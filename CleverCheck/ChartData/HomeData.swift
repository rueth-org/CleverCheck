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
        
        var specificEnergyCost: Cost {
            .init(amount: homeConsumptionNet.value / energyCost.amount)
        }
    }
    
    var id = UUID()
    let modelContext: ModelContext
    let homeConsumptions: [HomeConsumption]
    let timeBox: TimeBox
    
    var data: [String: Data] {
        var result = [String: Data]()
        
        // Step through the months
        let calendar = Calendar.current
        var currentDate = timeBox.timePeriod.start
        while currentDate <= timeBox.timePeriod.end {
            // Get the monthly contributions from each home consumption (one may span several months)
            let monthKeyDisplay = timeBox.getKeyForDate(currentDate)
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
                partialResult + consumption.totalCostForMonth(monthKey: monthKeyGrouping, isGross: UserSettings.shared.displayGrossPrices, useConsumptionFromRelatedChargingSessions: true)
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
    
    init(modelContext: ModelContext, location: Location, timeBox: TimeBox) throws {
        self.modelContext = modelContext
        self.timeBox = timeBox
        
        // Get all consumptions ending in time period and belonging to the location
        let start = timeBox.timePeriod.start
        let end = timeBox.timePeriod.end
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
}
