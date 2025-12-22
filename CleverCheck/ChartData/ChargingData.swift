//
//  ChargingData.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 21/12/2025.
//

import Foundation
import SwiftData

struct ChargingData: Identifiable {
    enum Resolution: Equatable {
        case yearly(date: Date)
        case monthly(date: Date)
    }

    var id = UUID()
    var resolution: Resolution
    var chargingSessions: [ChargingSession]
    
    var chargedEnergy: [String: Double] {
        switch resolution {
        case .yearly(_):
            var result = [String: Double]()
            for session in chargingSessions {
                let monthKey = DateFormatter.chartDisplayDateYearly.string(from: session.endTime)
                let energy = session.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value
                result[monthKey, default: 0] += energy
            }
            return result
        case .monthly(_):
            var result = [String: Double]()
            for session in chargingSessions {
                let dayKey = DateFormatter.chartDisplayDateMonthly.string(from: session.endTime)
                let energy = session.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value
                result[dayKey, default: 0] += energy
            }
            return result
        }
    }

    init(modelContext: ModelContext, vehicle: Car, resolution: Resolution) throws {
        self.resolution = resolution
        
        // Get the id of the vehicle
        let vehicleID = vehicle.persistentModelID
        
        // Get all chargingCostPlans related to this vehicle
        let planDescriptor = FetchDescriptor<ChargingCostPlan>(
            predicate: #Predicate { plan in
                plan.car?.persistentModelID == vehicleID
            }
        )
        let relatedPlans = try modelContext.fetch(planDescriptor)
        
        if !relatedPlans.isEmpty {
            // Compute concrete date range outside the predicate so it can be captured.
            let calendar = Calendar.current
            let start: Date
            let end: Date

            switch resolution {
            case .monthly(let date):
                // Start of the given month
                let startOfMonth = date.startDateOfMonth
                // Start of next month
                let endOfMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth)!
                start = startOfMonth
                end = endOfMonth
            case .yearly(let date):
                // Start of the given year
                let year = calendar.component(.year, from: date)
                let startOfYear = calendar.startOfDay(for: calendar.date(from: DateComponents(year: year, month: 1, day: 1))!)
                // Start of next year
                let endOfYear = calendar.date(byAdding: DateComponents(year: 1), to: startOfYear)!
                start = startOfYear
                end = endOfYear
            }

            // Get all sessions in time period
            let sessionDescriptor = FetchDescriptor<ChargingSession>(
                predicate: #Predicate { session in
                    session.endTime >= start && session.endTime < end
                },
                sortBy: [
                    .init(\.endTime)
                ]
            )
            let allSessionsInPeriod = try modelContext.fetch(sessionDescriptor)
            
            // Filter by charging cost plans related to the vehicle
            let relatedPlanIDs = Set(relatedPlans.map { $0.persistentModelID })
            self.chargingSessions = allSessionsInPeriod.filter({ $0.chargingCostPlan != nil && relatedPlanIDs.contains($0.chargingCostPlan!.persistentModelID) })
        } else {
            self.chargingSessions = []
        }
    }
}

