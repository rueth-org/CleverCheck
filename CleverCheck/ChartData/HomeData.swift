//
//  HomeData.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/12/2025.
//

import Foundation
import SwiftData

struct HomeData: Identifiable {
    struct Data {
        let homeConsumptionGross: Measurement<UnitEnergy>
        let homeConsumptionNet: Measurement<UnitEnergy>
        let energyCost: Cost
        
        var grossMinusNetConsumption: Measurement<UnitEnergy> {
            homeConsumptionGross.converted(to: .kilowattHours) - homeConsumptionNet.converted(to: .kilowattHours)
        }
    }
    
    var id = UUID()
    let homeConsumptions: [HomeConsumption]
    let relatedChargingCostPlans: [ChargingCostPlan]
    let startDate: Date
    let endDate: Date
    
    var data: [String: Data] {
        var result = [String: Data]()
        
        // Step through the months
        let calendar = Calendar.current
        var currentDate = startDate
        while currentDate < endDate {
            // Get the monthly contributions from each home consumption (one may span several months)
            let monthKeyDisplay = HomeData.dateKey(for: currentDate)
            let monthKeyGrouping = UserSettings.shared.groupingDateFormatter.string(from: currentDate)
            
            // Gross consumption
            let grossConsumption = homeConsumptions.reduce(0) { partialResult, consumption in
                partialResult + consumption.consumptionForMonth(monthKey: monthKeyGrouping, includeIfIncludedElsewhere: false)
            }
            
            // Net consumption
            let netConsumption = homeConsumptions.reduce(0) { partialResult, consumption in
                partialResult + consumption.netConsumptionForMonth(monthKey: monthKeyGrouping)
            }
            
            // Cost
            let cost = homeConsumptions.reduce(0) { partialResult, consumption in
                partialResult + consumption.totalCostForMonth(monthKey: monthKeyGrouping, isGross: UserSettings.shared.displayGrossPrices)
            }
            
            // Create data set
            result[monthKeyDisplay] = Data(
                homeConsumptionGross: .init(value: grossConsumption, unit: UserSettings.shared.energyUnit),
                homeConsumptionNet: .init(value: netConsumption, unit: UserSettings.shared.energyUnit),
                energyCost: Cost(amount: cost)
            )
            
            // Increase current date by one month
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
        }
        
        return result
    }
    
    init(modelContext: ModelContext, location: Location, date: Date) throws {
        // Get related charing cost plans
        let allPlans: [ChargingCostPlan] = try modelContext.fetch(FetchDescriptor<ChargingCostPlan>())
        self.relatedChargingCostPlans = allPlans.filter({ $0.relatedLocation != nil && $0.relatedLocation!.id == location.id })
        
        // Compute concrete date range outside the predicate so it can be captured.
        let calendar = Calendar.current
        
        // Start of the given year
        let year = calendar.component(.year, from: date)
        let start = calendar.startOfDay(for: calendar.date(from: DateComponents(year: year, month: 1, day: 1))!)
        // Start of next year
        let end = calendar.date(byAdding: DateComponents(year: 1), to: start)!
        
        self.startDate = start
        self.endDate = end

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
    
    static func dateKey(for time: Date) -> String {
        DateFormatter.chartDisplayDateYearly.string(from: time)
    }
}
