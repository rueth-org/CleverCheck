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
        case yearly(year: Int)
        case monthly(year: Int, month: Int)
    }

    var id = UUID()
    var chargingSessions: [ChargingSession]

    init(modelContext: ModelContext, vehicle: Car, resolution: Resolution) throws {
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
            case .monthly(let year, let month):
                // Start of the given month
                let startOfMonth = calendar.startOfDay(for: calendar.date(from: DateComponents(year: year, month: month, day: 1))!)
                // Start of next month
                let endOfMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth)!
                start = startOfMonth
                end = endOfMonth
            case .yearly(let year):
                // Start of the given year
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
