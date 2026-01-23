//
//  ChargingData.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 21/12/2025.
//

import Foundation
import SwiftData

struct ChargingData: Identifiable {
    let id = UUID()
    let modelContext: ModelContext
    let relatedPlans: [ChargingCostPlan]
    let timeBox: TimeBox
    let chargingSessions: [ChargingSession]
    
    var consumptionData: ConsumptionData? {
        try? ConsumptionData(modelContext: modelContext, timeBox: timeBox, relatedPlans: relatedPlans, sessions: chargingSessions)
    }
    
    var chargedEnergy: [String: Double] {
        var result = [String: Double]()
        for session in chargingSessions {
            let monthKey = timeBox.getKeyForDate(session.endTime)
            let energy = session.chargedEnergy(in: UserSettings.shared.energyUnit).value
            result[monthKey, default: 0] += energy
        }
        return result
    }
    
    var totalChargedEnergy: Measurement<UnitEnergy> {
        let totalEnergy = chargingSessions.map({ $0.chargedEnergy(in: UserSettings.shared.energyUnit).value }).reduce(0, +)
        return .init(value: totalEnergy, unit: UserSettings.shared.energyUnit)
    }
    
    var chargingCost: [String: Double] {
        switch timeBox.selectedResolution {
        case .yearly:
            var result = [String: Double]()
            for session in chargingSessions {
                let monthKey = DateFormatter.chartDisplayDateYearly.string(from: session.endTime)
                let cost = session.totalChargingCost
                result[monthKey, default: 0] += cost.amount
            }
            return result
        case .monthly:
            var result = [String: Double]()
            for session in chargingSessions {
                let dayKey = DateFormatter.chartDisplayDateMonthly.string(from: session.endTime)
                let cost = session.totalChargingCost
                result[dayKey, default: 0] += cost.amount
            }
            return result
        case .daily:
            var result = [String: Double]()
            // The exact localized date format string used by this formatter (e.g. "h:mm a" or localized variant)
            // This matches how `endTime.formatted(date: .omitted, time: .shortened)` would display the time.
            for session in chargingSessions {
                // Use the localized short time string as key (matches .shortened)
                let dayKey = DateFormatter.chartDisplayDateDaily.string(from: session.endTime)
                let cost = session.totalChargingCost
                result[dayKey, default: 0] += cost.amount
            }
            return result
        }
    }

    var totalChargingCost: Cost {
        let totalCost = chargingSessions.map({ $0.totalChargingCost.amount }).reduce(0, +)
        return .init(amount: totalCost).converted(to: UserSettings.shared.currencyIdentifier) ?? .init(amount: totalCost)
    }
    
    init(modelContext: ModelContext, vehicle: Car, timeBox: TimeBox) throws {
        self.modelContext = modelContext
        self.timeBox = timeBox
        
        // Get the id of the vehicle
        let vehicleID = vehicle.persistentModelID
        
        // Get all chargingCostPlans related to this vehicle
        let planDescriptor = FetchDescriptor<ChargingCostPlan>(
            predicate: #Predicate { plan in
                plan.car?.persistentModelID == vehicleID
            }
        )
        self.relatedPlans = try modelContext.fetch(planDescriptor)
        
        if !relatedPlans.isEmpty {
            // Compute concrete date range outside the predicate so it can be captured.
            let start = timeBox.timePeriod.start
            let end = timeBox.timePeriod.end

            // Get all sessions in time period
            let sessionDescriptor = FetchDescriptor<ChargingSession>(
                predicate: #Predicate { session in
                    start <= session.endTime && session.endTime <= end
                },
                sortBy: [
                    .init(\.endTime)
                ]
            )
            let allSessionsInPeriod = try modelContext.fetch(sessionDescriptor)
            
            // Filter by charging cost plans related to the vehicle
            let relatedPlanIDs = Set(relatedPlans.map { $0.persistentModelID })
            self.chargingSessions = allSessionsInPeriod.filter({
                $0.chargingCostPlan != nil && relatedPlanIDs.contains($0.chargingCostPlan!.persistentModelID)
            })
        } else {
            self.chargingSessions = []
        }
    }
}
