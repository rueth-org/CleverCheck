//
//  HomeData.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/12/2025.
//

import Foundation
import SwiftData

struct HomeData: Identifiable {
    enum DataType: String {
        case homeConsumption = "Home Consumption"
        case charging = "Charging"
    }
    
    struct Data: Identifiable, Comparable {
        let id = UUID()
        let timeKey: String
        let dataType: DataType
        let consumption: Measurement<UnitEnergy>
        let cost: Cost
        
        var specificCost: Cost {
            .init(amount: consumption.converted(to: UserSettings.shared.energyUnit).value / cost.amount)
        }
        
        static func < (lhs: HomeData.Data, rhs: HomeData.Data) -> Bool {
            lhs.timeKey < rhs.timeKey
        }
        
        static func == (lhs: HomeData.Data, rhs: HomeData.Data) -> Bool {
            lhs.timeKey == rhs.timeKey
        }
    }
    
    var id = UUID()
    let modelContext: ModelContext
    let homeConsumptions: [HomeConsumption]
    let timeBox: TimeBox
    
    var data: [Data] {
        var result = [Data]()
        
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
            
            let deltaConsumption = grossConsumption - netConsumption
            
            // Cost
            let grossCost = homeConsumptions.reduce(0) { partialResult, consumption in
                partialResult + consumption.totalCostForMonth(monthKey: monthKeyGrouping, isGross: UserSettings.shared.displayGrossPrices, useConsumptionFromRelatedChargingSessions: true).gross
            }
            
            let netCost = homeConsumptions.reduce(0) { partialResult, consumption in
                partialResult + consumption.totalCostForMonth(monthKey: monthKeyGrouping, isGross: UserSettings.shared.displayGrossPrices, useConsumptionFromRelatedChargingSessions: true).net
            }
            
            let deltaCost = grossCost - netCost
            
            // Create home consumption data set
            result.append(Data(
                timeKey: monthKeyDisplay,
                dataType: .homeConsumption,
                consumption: .init(value: grossConsumption, unit: UserSettings.shared.energyUnit),
                cost: .init(amount: grossCost)
            ))
            
            // Create charging data set
            result.append(Data(
                timeKey: monthKeyDisplay,
                dataType: .charging,
                consumption: .init(value: deltaConsumption, unit: UserSettings.shared.energyUnit),
                cost: .init(amount: deltaCost)
            ))
            
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
