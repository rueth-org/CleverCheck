//
//  ChargingCostPlan.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 28/11/2025.
//

import Foundation
import SwiftData
import UIKit

@Model
public final class ChargingCostPlan {
    enum PlanType: String, Codable, CustomStringConvertible {
        case individual = "Individual"
        case flatrate = "Flatrate"
        case homeConsumption = "Home Consumption"
        case homeDiscounted = "Home Discounted"
        case refunded = "Refunded"
        
        var description: String {
            NSLocalizedString(self.rawValue, comment: "")
        }
    }
    
    public var id: UUID = UUID()
    var car: Car?
    var charger: Charger?
    var planType: PlanType = PlanType.individual
    var defaultEnergyPrice: Cost?
    var energyUnitSymbol: String = UserSettings.shared.energyUnitSymbol
    var monthlyRate: Cost?
    var includedInOtherPlan: ChargingCostPlan?
    var displayColorString: String?
    var isArchived: Bool = false
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingSession.chargingCostPlan)
    var chargingSessions: [ChargingSession]?
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingCostPlan.includedInOtherPlan)
    var childCostPlans: [ChargingCostPlan]?
    
    var descriptionShortNoCar: String {
        "\(charger?.description ?? "Unknown charger")"
    }
    
    var descriptionShort: String {
        "\(car?.description ?? "Unknown car") - \(descriptionShortNoCar)"
    }
    
    var descriptionLongNoCar: String {
        "\(descriptionShortNoCar) (\(planType.description))"
    }
    
    var descriptionLong: String {
        "\(descriptionShort) (\(planType.description))"
    }
    
    var displayColor: DisplayColor {
        set {
            displayColorString = newValue.rawValue
        }
        get {
            if let displayColorString {
                return DisplayColor(rawValue: displayColorString) ?? .blue
            } else {
                return DisplayColorFactory.shared.add(legendEntry: descriptionShortNoCar, to: ChargingCostPlan.classString())
            }
        }
    }

    init(
        car: Car,
        charger: Charger,
        planType: PlanType,
        defaultEnergyPrice: Cost? = nil,
        monthlyRate: Cost? = nil,
        includedInOtherPlan: ChargingCostPlan? = nil,
        displayColor: DisplayColor? = nil
    ) {
        self.car = car
        self.charger = charger
        self.planType = planType
        self.defaultEnergyPrice = defaultEnergyPrice
        self.monthlyRate = monthlyRate
        self.includedInOtherPlan = includedInOtherPlan
        self.displayColorString = displayColor?.rawValue
    }
    
    @MainActor
    func chargingSessions(in timeBox: TimeBox) -> [ChargingSession] {
        guard let chargingSessions else { return [] }
        return chargingSessions.filter { session in
            timeBox.contains(session.endTime)
        }
    }
    
    @MainActor
    func chargedEnergy(in timeBox: TimeBox, groupingKey: Bool) -> [String: Measurement<UnitEnergy>] {
        let filteredSessions = chargingSessions(in: timeBox)
        guard !filteredSessions.isEmpty else { return [:] }
        var result = [String: Measurement<UnitEnergy>]()
        for session in filteredSessions {
            let keys = timeBox.getKeysForDate(session.endTime)
            let key = groupingKey ? keys.grouping : keys.display
            let existing = result[key] ?? Measurement<UnitEnergy>(value: 0.0, unit: .kilowattHours)
            // Sum energies; ChargingCostPlan.totalChargedEnergy returns a Measurement in kWh
            result[key] = existing + session.chargedEnergy
        }
        return result
    }
    
    @MainActor
    func totalChargedEnergy(in timeBox: TimeBox) -> Measurement<UnitEnergy> {
        let filteredSessions = chargingSessions(in: timeBox)
        guard !filteredSessions.isEmpty else { return .init(value: 0.0, unit: .kilowattHours) }
        return filteredSessions.reduce(.init(value: 0.0, unit: .kilowattHours)) { $0 + ($1.chargedEnergy) }
    }
    
    @MainActor
    func totalChargingCost(in timeBox: TimeBox, modelContext: ModelContext) async -> (direct: Cost, indirect: Cost) {
        let filteredSessions = chargingSessions(in: timeBox)
        guard !filteredSessions.isEmpty else { return (direct: .init(amount: 0.0), indirect: .init(amount: 0.0)) }
        let directCost = filteredSessions.reduce(.init(amount: 0.0)) { $0 + ($1.totalChargingCost) }
        var modCounter = 0
        let indirectCost = await filteredSessions.asyncReduce(.init(amount: 0.0)) { partialResult, session in
            if let estimatedRealCost = session.estimatedRealCost {
                return partialResult + estimatedRealCost
            } else if let estimatedRealCost = try? await session.estimateRealCost(modelContext: modelContext).cost {
                session.estimatedRealCost = estimatedRealCost
                modCounter += 1
                return partialResult + estimatedRealCost
            } else {
                return partialResult
            }
        }
        
        if modCounter > 0 {
            try? modelContext.save()
        }
        
        return (direct: directCost, indirect: indirectCost)
    }
    
    class func classString() -> String {
        return NSStringFromClass(self)
    }
}

private extension Array {
    func asyncReduce<Result>(_ initialResult: Result, _ nextPartialResult: (Result, Element) async throws -> Result) async rethrows -> Result {
        var result = initialResult
        for element in self {
            result = try await nextPartialResult(result, element)
        }
        return result
    }
}
