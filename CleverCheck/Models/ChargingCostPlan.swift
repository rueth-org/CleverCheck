//
//  ChargingCostPlan.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 28/11/2025.
//

import Foundation
import SwiftData

@Model
public final class ChargingCostPlan {
    enum PlanType: String, Codable, CustomStringConvertible {
        case individual = "Individual"
        case flatrate = "Flatrate"
        case homeConsumption = "Home Consumption"
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

    init(
        car: Car,
        charger: Charger,
        planType: PlanType,
        defaultEnergyPrice: Cost? = nil,
        monthlyRate: Cost? = nil,
        includedInOtherPlan: ChargingCostPlan? = nil
    ) {
        self.car = car
        self.charger = charger
        self.planType = planType
        self.defaultEnergyPrice = defaultEnergyPrice
        self.monthlyRate = monthlyRate
        self.includedInOtherPlan = includedInOtherPlan
    }
    
    func chargedEnergy(in timeBox: TimeBox) -> [String: Measurement<UnitEnergy>] {
        guard let chargingSessions else { return [:] }
        let filteredSessions = chargingSessions.filter { session in
            timeBox.contains(session.endTime)
        }
        var result = [String: Measurement<UnitEnergy>]()
        for session in filteredSessions {
            let key = timeBox.getKeyForDate(session.endTime)
            let existing = result[key] ?? Measurement<UnitEnergy>(value: 0.0, unit: .kilowattHours)
            // Sum energies; ChargingCostPlan.totalChargedEnergy returns a Measurement in kWh
            result[key] = existing + session.chargedEnergy
        }
        return result
    }
    
    func totalChargedEnergy(in timeBox: TimeBox) -> Measurement<UnitEnergy> {
        guard let chargingSessions else { return .init(value: 0.0, unit: .kilowattHours) }
        let filteredSessions = chargingSessions.filter { session in
            timeBox.contains(session.endTime)
        }
        return filteredSessions.reduce(.init(value: 0.0, unit: .kilowattHours)) { $0 + ($1.chargedEnergy) }
    }
    
    func totalChargingCost(in timeBox: TimeBox) -> Cost {
        guard let chargingSessions else { return .init(amount: 0.0) }
        let filteredSessions = chargingSessions.filter { session in
            timeBox.contains(session.endTime)
        }
        return filteredSessions.reduce(.init(amount: 0.0)) { $0 + ($1.totalChargingCost) }
    }
}

