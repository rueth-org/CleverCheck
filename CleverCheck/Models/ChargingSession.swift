//
//  ChargingSession.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class ChargingSession {
    enum CostCalculationMethod: Codable {
        case absolute
        case specific
        case both
        case none
        
        func description() -> LocalizedStringKey {
            switch self {
            case .absolute: return "Absolut cost"
            case .specific: return "Specific cost"
            case .both: return "Absolut and specific cost"
            case .none: return "No cost"
            }
        }
    }
    
    var id: UUID = UUID()
    var startTime: Date?
    var endTime: Date = Date.now
    var chargedEnergyKWh: Double = 0.0
    var chargingCostPlan: ChargingCostPlan?
    var chargingCost: Cost?
    var specificChargingCost: Cost?
    var costCalculationMethod: CostCalculationMethod = CostCalculationMethod.none
    var mileageKilometer: Double?
    var initialSOC: Double?
    var finalSOC: Double?
    var comment: String?
    
    @Transient var chargedEnergy: Measurement<UnitEnergy> {
        get {
            return Measurement<UnitEnergy>(value: chargedEnergyKWh, unit: .kilowattHours)
        }
        set {
            chargedEnergyKWh = newValue.converted(to: .kilowattHours).value
        }
    }
    
    @Transient var mileage: Measurement<UnitLength>? {
        get {
            if let mileageKilometer {
                return Measurement<UnitLength>(value: mileageKilometer, unit: .kilometers)
            } else {
                return nil
            }
        }
        set {
            mileageKilometer = newValue?.converted(to: .kilometers).value
        }
    }
    
    var description: String {
        "\(UserSettings.shared.shortDateFormatter.string(from: endTime)) - \(chargingCostPlan?.descriptionLong ?? "Unknown plan"): \(chargedEnergyFormatted)"
    }
    
    var chargedEnergyFormatted: String {
        String(format: "%.1f \(UserSettings.shared.energyUnit.symbol)", chargedEnergy.converted(to: UserSettings.shared.energyUnit).value)
    }
    
    var totalChargingCost: Cost {
        switch costCalculationMethod {
        case .none: return .init(amount: 0.0)
        case .absolute: return self.chargingCost ?? .init(amount: 0.0)
        case .specific:
            var totalCost = 0.0
            if let specificChargingCost {
                totalCost += specificChargingCost.amount * chargedEnergy(in: UserSettings.shared.energyUnit).value
            }
            return .init(amount: totalCost)
        case .both:
            var totalCost = 0.0
            if let specificChargingCost {
                totalCost += specificChargingCost.amount * chargedEnergy(in: UserSettings.shared.energyUnit).value
            }
            if let chargingCost {
                totalCost += chargingCost.amount
            }
            return .init(amount: totalCost)
        }
    }
    
    init(
        startTime: Date? = nil,
        endTime: Date,
        chargedEnergy: Measurement<UnitEnergy>,
        chargingCostPlan: ChargingCostPlan,
        chargingCost: Cost? = nil,
        specificChargingCost: Cost? = nil,
        costCalculationMethod: CostCalculationMethod = .none,
        mileage: Measurement<UnitLength>? = nil,
        initialSOC: Double? = nil,
        finalSOC: Double? = nil,
        useDefaultFinalSOC: Bool = false,
        comment: String? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.chargedEnergyKWh = chargedEnergy.converted(to: .kilowattHours).value
        self.chargingCostPlan = chargingCostPlan
        self.chargingCost = chargingCost
        self.specificChargingCost = specificChargingCost
        self.costCalculationMethod = costCalculationMethod
        self.mileageKilometer = mileage?.converted(to: .kilometers).value
        self.initialSOC = initialSOC
        if useDefaultFinalSOC, chargingCostPlan.car != nil {
            self.finalSOC = chargingCostPlan.car!.defaultSOC
        } else {
            self.finalSOC = finalSOC
        }
        self.comment = comment
    }
    
    func chargedEnergy(in unitEnergy: UnitEnergy) -> Measurement<UnitEnergy> {
        chargedEnergy.converted(to: unitEnergy)
    }
}
