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
        case homeConsumption = "Home consumption"
        case charging = "Charging"
    }
    
    struct Data: Identifiable, Comparable {
        let id = UUID()
        let timeKey: String
        let dataType: DataType
        let consumption: Measurement<UnitEnergy>
        let cost: Cost
        
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
        if let timePeriod = timeBox.timePeriod {
            var result = [Data]()
            
            // Step through the months
            let calendar = Calendar.current
            var currentDate = timePeriod.start
            while currentDate <= timePeriod.end {
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
                    consumption: .init(value: netConsumption, unit: UserSettings.shared.energyUnit),
                    cost: .init(amount: netCost)
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
        } else {
            return []
        }
    }
    
    var consumedEnergy: (total: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>) {
        let totalEnergy = homeConsumptions
            .filter { $0.consumptionIncludedElsewhere == false }
            .map({ $0.consumption.converted(to: UserSettings.shared.energyUnit).value }).reduce(0, +)
        let chargedEnergy = homeConsumptions
            .filter { $0.consumptionIncludedElsewhere == true }
            .map({ $0.consumption.converted(to: UserSettings.shared.energyUnit).value}).reduce(0, +)
        return (
            total: .init(value: totalEnergy, unit: UserSettings.shared.energyUnit),
            charging: .init(value: chargedEnergy, unit: UserSettings.shared.energyUnit)
        )
    }
    
    var cost: (home: Cost, charging: Cost) {
        let allCost = homeConsumptions.map { $0.totalCost(isGross: UserSettings.shared.displayGrossPrices) }
        let gross = allCost.reduce(0.0) { $0 + $1.gross }
        let net = allCost.reduce(0.0) { $0 + $1.net }
        
        return (
            home: .init(amount: net),
            charging: .init(amount: gross - net)
        )
    }
    
    init(modelContext: ModelContext, location: Location, timeBox: TimeBox) throws {
        self.modelContext = modelContext
        self.timeBox = timeBox
        
        var descriptor: FetchDescriptor<HomeConsumption>
        if let timePeriod = timeBox.timePeriod {
            // Get all consumptions ending in time period and belonging to the location
            let start = timePeriod.start
            let end = timePeriod.end
            descriptor = FetchDescriptor<HomeConsumption>(
                predicate: #Predicate { consumption in
                    consumption.validUntil >= start && consumption.validUntil <= end
                },
                sortBy: [
                    .init(\.validUntil)
                ]
            )
        } else {
            descriptor = FetchDescriptor<HomeConsumption>(
                sortBy: [
                    .init(\.validUntil)
                ]
            )
        }
        let allConsumptionsInPeriod = try modelContext.fetch(descriptor)
        
        // Filter by location
        self.homeConsumptions = allConsumptionsInPeriod.filter({
            $0.associatedLocation != nil && $0.associatedLocation!.persistentModelID == location.persistentModelID
        })
    }
}
