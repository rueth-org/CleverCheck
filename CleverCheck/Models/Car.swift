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
    struct EnergyData: Identifiable {
        let id = UUID()
        let description: String
        let chargedEnergy: Measurement<UnitEnergy>
    }
    
    struct CostData: Identifiable {
        let id = UUID()
        let description: String
        let cost: Cost
    }
    
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
    
    init(make: String, model: String, defaultSOC: Double = 0.8) {
        self.make = make
        self.model = model
        self.defaultSOC = defaultSOC
    }
    
    func chargingSessions(in timeBox: TimeBox?) -> [ChargingSession] {
        guard let chargingCostPlans else { return [] }
        if let timeBox {
            return chargingCostPlans.flatMap { $0.chargingSessions ?? [] }.filter { timeBox.contains($0.endTime) }
        } else {
            return chargingCostPlans.flatMap { $0.chargingSessions ?? [] }
        }
    }
    
    func chargedEnergy(in timeBox: TimeBox) -> [EnergyData] {
        guard let chargingCostPlans else { return [] }
        var result = [EnergyData]()
        for plan in chargingCostPlans {
            result.append(EnergyData(description: plan.descriptionShortNoCar, chargedEnergy: plan.totalChargedEnergy(in: timeBox)))
        }
        return result
    }
    
    func chargedEnergyPerPeriod(in timeBox: TimeBox) -> [String: [EnergyData]] {
        guard let chargingCostPlans else { return [:] }
        var result = [String: [EnergyData]]()
        for plan in chargingCostPlans {
            let chargedEnergyPerPeriod = plan.chargedEnergy(in: timeBox)
            for key in chargedEnergyPerPeriod.keys {
                let energyDataSet = EnergyData(description: plan.descriptionShortNoCar, chargedEnergy: chargedEnergyPerPeriod[key]!)
                if result[key] == nil {
                    result[key] = [energyDataSet]
                } else {
                    result[key]?.append(energyDataSet)
                }
            }
        }
        return result
    }
    
    func chargingCost(in timeBox: TimeBox) -> [CostData] {
        guard let chargingCostPlans else { return [] }
        var result = [CostData]()
        for plan in chargingCostPlans {
            result.append(CostData(description: plan.descriptionShortNoCar, cost: plan.totalChargingCost(in: timeBox)))
        }
        return result
    }
    
    func consumptionData(in timeBox: TimeBox, modelContext: ModelContext) -> ConsumptionData? {
        guard let chargingCostPlans else { return nil }
        let chargingSessions = chargingSessions(in: timeBox)
        if chargingSessions.isEmpty { return nil }
        
        return try? ConsumptionData(modelContext: modelContext, timeBox: timeBox, relatedPlans: chargingCostPlans, sessions: chargingSessions)
    }
    
    func averageEnergyPerPercentPoint(in timeBox: TimeBox? = nil) -> Measurement<UnitEnergy>? {
        let chargingSessions = self.chargingSessions(in: timeBox)
        let sessionsWithPercentAndEnergy = chargingSessions.filter { session in
            if let initial = session.initialSOC, let final = session.finalSOC {
                return final > initial && session.chargedEnergyKWh > 0
            }
            return false
        }

        let values: [Double] = sessionsWithPercentAndEnergy.compactMap { session in
            guard let initial = session.initialSOC, let final = session.finalSOC, final > initial else { return nil }
            let percentDiff = final - initial
            if percentDiff == 0 { return nil }
            return session.chargedEnergyKWh / percentDiff
        }

        guard !values.isEmpty else {
            // Return 0 kWh per percent point if no valid sessions
            return nil
        }

        let average = values.reduce(0, +) / Double(values.count)
        return Measurement(value: average, unit: UnitEnergy.kilowattHours)
    }
}

