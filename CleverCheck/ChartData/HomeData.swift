//
//  HomeData.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/12/2025.
//

import Foundation
import SwiftData

struct HomeData: Identifiable {
    enum Resolution: Equatable {
        case yearly(date: Date)
        case monthly(date: Date)
    }
    
    var id = UUID()
    let homeConsumptions: [HomeConsumption]
    
    init(modelContext: ModelContext, location: Location, resolution: Resolution) throws {
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

        // Get all consumptions ending in time period and belonging to the location
        let descriptor = FetchDescriptor<HomeConsumption>(
            predicate: #Predicate { consumption in
                consumption.validUntil >= start && consumption.validUntil < end
            },
            sortBy: [
                .init(\.validUntil)
            ]
        )
        let allConsumptionsInPeriod = try modelContext.fetch(descriptor)
        
        // Filter by location
        self.homeConsumptions = allConsumptionsInPeriod.filter({
            $0.associatedLocation != nil && $0.associatedLocation!.persistentModelID == location.persistentModelID
        })
    }
    
    static func dateKey(for time: Date, with resolution: HomeData.Resolution) -> String {
        switch resolution {
        case .yearly(_): DateFormatter.chartDisplayDateYearly.string(from: time)
        case .monthly(_): DateFormatter.chartDisplayDateMonthly.string(from: time)
        }
    }
}
