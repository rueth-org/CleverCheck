//
//  Car.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData

@Model
final class Car {
    var id: UUID = UUID()
    var make: String = ""
    var model: String = ""
    var defaultSOC: Double = 0.8
    var netBatteryCapacityKWh: Double?
    var maxChargingPowerkW: Double?
    var isArchived: Bool = false
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingCostPlan.car)
    var chargingCostPlans: [ChargingCostPlan]?
    
    var description: String {
        return "\(make) \(model)"
    }
    
    var chargedEnergy: [String: Measurement<UnitEnergy>] {
        guard let chargingCostPlans else { return [:] }
        var result: [String: Measurement<UnitEnergy>] = [:]
        for plan in chargingCostPlans {
            let key = plan.descriptionShortNoCar
            let existing = result[key] ?? Measurement<UnitEnergy>(value: 0.0, unit: .kilowattHours)
            // Sum energies; ChargingCostPlan.totalChargedEnergy returns a Measurement in kWh
            result[key] = existing + plan.totalChargedEnergy
        }
        return result
    }
    
    var totalChargedEnergy: Measurement<UnitEnergy> {
        chargedEnergy.values.reduce(Measurement<UnitEnergy>(value: 0.0, unit: .kilowattHours), +)
    }
    
    var chargingCost: [String: Cost] {
        guard let chargingCostPlans else { return [:] }
        var result: [String: Cost] = [:]
        for plan in chargingCostPlans {
            let key = plan.descriptionShortNoCar
            let existing = result[key] ?? Cost(amount: 0.0, currency: UserSettings.shared.currencyIdentifier)
            // Sum cost
            result[key] = existing + plan.totalChargingCost
        }
        return result
    }
    
    var totalChargingCost: Cost {
        chargingCost.values.reduce(Cost(amount: 0.0, currency: UserSettings.shared.currencyIdentifier), +)
    }
    
    init(make: String, model: String, defaultSOC: Double = 0.8) {
        self.make = make
        self.model = model
        self.defaultSOC = defaultSOC
    }
}
