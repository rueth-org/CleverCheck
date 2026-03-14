//
//  Location.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Location: Identifiable {
    enum DataType: String {
        case total = "Total"
        case homeConsumption = "Home consumption"
        case homeCharging = "Home charging"
        case refundedCharging = "Refunded charging"
        case discount = "Discount"
        
        func color() -> DisplayColor {
            switch self {
            case .total:
                return .blue
            case .homeConsumption:
                return .red
            case .homeCharging:
                return .yellow
            case .refundedCharging:
                return .orange
            case .discount:
                return .pink
            }
        }
    }
    
    struct Data: Identifiable, Comparable, GraphItem {
        let id = UUID()
        let groupingKey: String
        let displayKey: String
        let dataType: DataType
        let consumption: Measurement<UnitEnergy>
        let cost: Cost
        
        var legendLabel: String {
            dataType.rawValue
        }
        
        var displayColor: DisplayColor {
            dataType.color()
        }
        
        static func < (lhs: Location.Data, rhs: Location.Data) -> Bool {
            lhs.displayKey < rhs.displayKey
        }
        
        static func == (lhs: Location.Data, rhs: Location.Data) -> Bool {
            lhs.displayKey == rhs.displayKey
        }
    }
    
    var id: UUID = UUID()
    var name: String = ""
    var isArchived: Bool = false
    
    @Relationship(deleteRule: .nullify, inverse: \HomeConsumption.associatedLocation)
    var associatedHomeConsumptions: [HomeConsumption]?
    
    @Relationship(deleteRule: .nullify, inverse: \Charger.location)
    var chargers: [Charger]?
    
    init(name: String) {
        self.name = name
    }
    
    /// Returns all related home consumptions in the given time box, or all if no time box is given.
    /// - Parameter timeBox: The given time box.
    /// - Returns: The home consumptions in the given time box.
    func homeConsumptions(in timeBox: TimeBox?) -> [HomeConsumption] {
        guard let associatedHomeConsumptions else { return [] }
        if let timeBox {
            return associatedHomeConsumptions.filter { timeBox.contains($0.validUntil) }.sorted(by: { $0.validUntil < $1.validUntil})
        } else {
            return associatedHomeConsumptions.sorted(by: { $0.validUntil < $1.validUntil})
        }
    }
    
    func data(in timeBox: TimeBox, useRelatedConsumption: Bool, modelContext: ModelContext) -> [Data] {
        // Build a cache key using essential inputs that influence the result
        let startTs = timeBox.timePeriod?.start.timeIntervalSince1970 ?? 0
        let endTs = timeBox.timePeriod?.end.timeIntervalSince1970 ?? 0
        let key = "loc:" + id.uuidString + "|res:\(timeBox.selectedResolution)|start:\(startTs)|end:\(endTs)|gross:\(UserSettings.shared.displayGrossPrices)|energyUnit:\(UserSettings.shared.energyUnit.symbol)|useRelatedConsumption:\(UserSettings.shared.useRelatedConsumptions.description)"

        // Try cached value
        if let cached = Location.cachedData(forKey: key) {
            return cached
        }

        guard let timePeriod = timeBox.timePeriod else { return [] }
        let homeConsumptions = homeConsumptions(in: timeBox)
        var result = [Data]()

        // Fast-path when no consumptions
        if homeConsumptions.isEmpty {
            Location.storeCachedData(result, forKey: key)
            return []
        }

        // Precompute per-consumption month dictionaries to avoid repeated work inside the month loop
        var totalConsumptionPerMonth: [[String: Measurement<UnitEnergy>]] = []
        var totalCostPerMonth: [[String: Cost]] = []
        var homeChargingConsumptionPerMonth: [[String: Measurement<UnitEnergy>]] = []
        var homeChargingCostPerMonth: [[String: Cost]] = []

        for consumption in homeConsumptions {
            if !consumption.consumptionIncludedElsewhere {
                // The consumption is not included elsewhere, i.e., it's part of the total consumption
                totalConsumptionPerMonth.append(consumption.consumptionPerMonth(includeIfIncludedElsewhere: false, useRelatedConsumptions: useRelatedConsumption))
                totalCostPerMonth.append(consumption.totalCostPerMonth(includingVAT: UserSettings.shared.displayGrossPrices, useRelatedConsumptions: useRelatedConsumption))
            } else {
                // The consumption is included elsewhere, i.e., it's part of the home charging consumption
                homeChargingConsumptionPerMonth.append(consumption.consumptionPerMonth(includeIfIncludedElsewhere: true, useRelatedConsumptions: useRelatedConsumption))
                homeChargingCostPerMonth.append(consumption.totalCostPerMonth(includingVAT: UserSettings.shared.displayGrossPrices, useRelatedConsumptions: useRelatedConsumption))
            }
        }
        
        // Up to this point, we have the total consumption and the home charging portion of it.
        // The home charging portion only exists, if there has been a separate consumption for it, e.g., in case of "refusion" in DK up to 2025, and its cost would only contain the refunded part of the cost, i.e., be negative
        
        // Get the refunded sessions related to this location in the given time period
        let refundedPerMonth = refundedPerMonth(in: timeBox, modelContext: modelContext)
        
        // Get the related charging consumptions for this location in the given time period, excluding refunded and discounted sessions
        let relatedChargingConsumptions = relatedChargingConsumptionsPerMonth(in: timeBox)
        
        // Step through the months and aggregate from precomputed maps
        let calendar = Calendar.current
        var currentDate = timePeriod.start
        while currentDate <= timePeriod.end {
            let monthKeys = timeBox.getKeysForDate(currentDate)
            
            // Sum up the total consumption and cost for this month from all home consumptions, using the precomputed maps, to avoid doing the summation for each month inside the loop over home consumptions, which would be computationally expensive.
            var totalConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var totalCost: Cost = .init(amount: 0.0)
            for idx in totalConsumptionPerMonth.indices {
                totalConsumption = totalConsumption + (totalConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
                totalCost += totalCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // Initialize total incl. refunds with the total values
            var totalConsumptionInclRefunds = totalConsumption
            var totalCostInclRefunds = totalCost
            
            // If there is a refunded session in this month, subtract its consumption and cost from the total values and add them to the refunded part.
            var refundedConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var refundedCost: Cost = .init(amount: 0.0)
            if let refundedData = refundedPerMonth[monthKeys.grouping] {
                totalConsumptionInclRefunds = totalConsumptionInclRefunds - refundedData.consumption
                refundedConsumption = refundedConsumption + refundedData.consumption
                totalCostInclRefunds += refundedData.cost // refundedData.cost is a negative value, so we add it to homeCost to reduce its value
                refundedCost -= refundedData.cost // refundedData.cost is a negative value, so we subtract it from refundedCost to increase its value
            }
            
            // Initialize the home consumption values with the home consumption incl. refunds
            var homeConsumption = totalConsumptionInclRefunds
            var homeCost = totalCostInclRefunds
            
            // If there are charging sesssions from related charging cost plans, ...
            var homeChargingConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var homeChargingCost: Cost = .init(amount: 0.0)
            if let relatedConsumption = relatedChargingConsumptions[monthKeys.grouping] {
                // Determine the cost portion of home cost incl. refunds related to charging
                let chargingCostPortion = Cost(amount: totalCostInclRefunds.amount * relatedConsumption.converted(to: UserSettings.shared.energyUnit).value / totalConsumptionInclRefunds.converted(to: UserSettings.shared.energyUnit).value)
                
                // Subtract the related charging consumption from the home consumption and add them to the charging part.
                homeConsumption = homeConsumption - relatedConsumption
                homeChargingConsumption = homeChargingConsumption + relatedConsumption
                
                // Subtract the related charging cost portion from the home cost and add it to the charging cost, so that the costs are correctly allocated to home and charging part.
                homeCost -= chargingCostPortion
                homeChargingCost += chargingCostPortion
            }

            // Determine the discounted home charging
            var discountConsumption = Measurement(value: 0.0, unit: UserSettings.shared.energyUnit)
            var discountCost = Cost(amount: 0.0)
            for idx in homeChargingCostPerMonth.indices {
                discountConsumption = discountConsumption + (homeChargingConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
                // This is the discounted home charging cost, which is a negative value, so we add it to the home charging cost to reduce it.
                discountCost -= homeChargingCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // Only subtract the cost, the consumption is already included in the home charging consumption, as the discount is a cost discount on the home charging consumption, but not an energy discount, so it does not reduce the consumed energy, only the cost of it.
            homeChargingCost -= discountCost

            // Create total consumption data set
            if totalConsumption.value != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .total,
                    consumption: totalConsumption,
                    cost: totalCost
                ))
            }

            // Create home consumption data set
            if homeConsumption.value != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .homeConsumption,
                    consumption: homeConsumption,
                    cost: homeCost
                ))
            }
            
            // Create discount data set
            if discountConsumption.value != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .discount,
                    consumption: discountConsumption,
                    cost: discountCost
                ))
            }

            // Create home charging data set
            if homeChargingConsumption.value != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .homeCharging,
                    consumption: homeChargingConsumption,
                    cost: homeChargingCost
                ))
            }
            
            // Create the refunded charging data set only if there is a refunded session in this month, otherwise we would have an unnecessary data set with zero values, which would add clutter to the graph and legend.
            if refundedConsumption.value != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .refundedCharging,
                    consumption: refundedConsumption,
                    cost: refundedCost
                ))
            }

            // Increase current date by one month
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
        }

        // Store in cache before returning
        Location.storeCachedData(result, forKey: key)
        return result
    }

    // MARK: - Simple in-memory cache for data(in:)
    private struct CacheEntry {
        let timestamp: Date
        let data: [Data]
    }

    private static var cache: [String: CacheEntry] = [:]
    private static let cacheQueue = DispatchQueue(label: "CleverCheck.Location.data.cache", attributes: .concurrent)
    private static let cacheTTL: TimeInterval = 60 // seconds

    private static func cachedData(forKey key: String) -> [Data]? {
        var entry: CacheEntry?
        cacheQueue.sync {
            entry = cache[key]
        }
        if let entry = entry {
            if Date().timeIntervalSince(entry.timestamp) <= cacheTTL {
                return entry.data
            } else {
                // expired; remove it
                cacheQueue.async(flags: .barrier) {
                    cache.removeValue(forKey: key)
                }
            }
        }
        return nil
    }

    private static func storeCachedData(_ data: [Data], forKey key: String) {
        let entry = CacheEntry(timestamp: Date(), data: data)
        cacheQueue.async(flags: .barrier) {
            cache[key] = entry
        }
    }

    /// Public helper to manually invalidate the cache for a specific key or all keys
    static func invalidateCache(forKey key: String? = nil) {
        if let key = key {
            cacheQueue.async(flags: .barrier) {
                cache.removeValue(forKey: key)
            }
        } else {
            cacheQueue.async(flags: .barrier) {
                cache.removeAll()
            }
        }
    }

    func consumedEnergy(in timeBox: TimeBox) -> (total: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>) {
        let homeConsumptions = homeConsumptions(in: timeBox)
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
    
    /// Returns the refunded consumption and cost for the given time box. Only considers charging sessions of type .refunded that are related to this location via their charger.
    /// - Parameters:
    ///   - timeBox: The time box to limit the charging sessions to.
    ///   - modelContext: The model context to fetch data from.
    /// - Returns: A tuple containing the refunded consumption and refunded cost.
    func refunded(in timeBox: TimeBox, modelContext: ModelContext) -> (consumption: Measurement<UnitEnergy>, cost: Cost) {
        // Load all charging cost plans
        let request = FetchDescriptor<ChargingCostPlan>(predicate: #Predicate<ChargingCostPlan> { _ in true })
        var allPlans: [ChargingCostPlan]
        do {
            allPlans = try modelContext.fetch(request)
        } catch {
            return (Measurement<UnitEnergy>(value: 0.0, unit: UserSettings.shared.energyUnit), .init(amount: 0.0))
        }
        
        // Filter by plans of type .refunded
        let refundedPlans = allPlans.filter { $0.planType == .refunded }
        
        // Get all plans, the chargers of which are related to the location
        let allRelatedPlans = refundedPlans.filter { plan in
            plan.charger?.location == self
        }
        
        // Get all charging session for these plans in the given time box
        // Flatten child plan chargingSessions (optional arrays) into a single [ChargingSession]
        let relatedSessionsInRange: [ChargingSession] = allRelatedPlans.flatMap { $0.chargingSessions(in: timeBox) }
        
        // Get related consumption
        let relatedConsumption = relatedSessionsInRange.reduce(0.0) { partialResult, session in
            partialResult + session.chargedEnergyKWh
        }
        
        // Multiply the session consumption with the specific price of the home consumption
        let totalRefunded = relatedSessionsInRange.reduce(0.0) { partialResult, session in
            partialResult + session.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value * (session.relatedHomeConsumption?.sumOfPriceElementsByConsumption.amount ?? 0.0)
        }
        
        return (Measurement<UnitEnergy>(value: relatedConsumption, unit: UserSettings.shared.energyUnit), .init(amount: totalRefunded))
    }
    
    /// Returns the refunded consumption and cost per month for the given time box. Only considers charging sessions of type .refunded that are related to this location via their charger.
    /// - Parameters:
    ///   - timeBox: The time box to limit the charging sessions to.
    ///   - modelContext: The model context to fetch data from.
    /// - Returns: An set of tuples with the month as key (formatted as string) and refunded consumption and refunded cost for each month in the time box as values.
    func refundedPerMonth(in timeBox: TimeBox, modelContext: ModelContext) -> [String: (consumption: Measurement<UnitEnergy>, cost: Cost)] {
        // Load all charging cost plans
        let request = FetchDescriptor<ChargingCostPlan>(predicate: #Predicate<ChargingCostPlan> { _ in true })
        var allPlans: [ChargingCostPlan]
        do {
            allPlans = try modelContext.fetch(request)
        } catch {
            return [:]
        }
        
        // Filter by plans of type .refunded
        let refundedPlans = allPlans.filter { $0.planType == .refunded }
        
        // Get all plans, the chargers of which are related to the location
        let allRelatedPlans = refundedPlans.filter { plan in
            plan.charger?.location == self
        }
        
        // Get all charging session for these plans in the given time box
        // Flatten child plan chargingSessions (optional arrays) into a single [ChargingSession]
        let relatedSessionsInRange: [ChargingSession] = allRelatedPlans.flatMap { $0.chargingSessions(in: timeBox) }
        
        // Group by month and aggregate consumption and cost
        var monthlyData: [String: (consumption: Double, cost: Double)] = [:]
        
        for session in relatedSessionsInRange {
            let monthKey = UserSettings.shared.groupingDateFormatter.string(from: session.endTime)
            
            // Get the consumption from the session
            monthlyData[monthKey, default: (consumption: 0.0, cost: 0.0)].consumption += session.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value
            
            // Use the specific price of the home consumption for the cost calculation. Multiply the session consumption with the specific price of the home consumption to get the cost of the refunded session, which is a negative value, and add it to the monthly cost.
            monthlyData[monthKey, default: (consumption: 0.0, cost: 0.0)].cost += session.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value * (session.relatedHomeConsumption?.sumOfPriceElementsByConsumption.amount ?? 0.0)
        }
        
        // Convert to Measurement and Cost types
        var result: [String: (consumption: Measurement<UnitEnergy>, cost: Cost)] = [:]
        for (month, data) in monthlyData {
            result[month] = (consumption: Measurement<UnitEnergy>(value: data.consumption, unit: UserSettings.shared.energyUnit), cost: Cost(amount: data.cost))
        }
        return result
    }
    
    func relatedChargingConsumptionsPerMonth(in timeBox: TimeBox) -> [String: Measurement<UnitEnergy>] {
        // Get all plans related to the location via their charger
        let allRelatedPlans = chargers?.flatMap { $0.chargingCostPlans ?? [] } ?? []
        
        // Filter by plans, which are not .refunded, as they are covered by the refunded plans
        let filteredPlans = allRelatedPlans.filter { $0.planType != .refunded }
        
        // Consolidate the monthly consumptions of all filtered plans into a single month map
        var monthlyConsumptions: [String: Measurement<UnitEnergy>] = [:]
        for plan in filteredPlans {
            let consumptions = plan.chargedEnergy(in: timeBox, groupingKey: true)
            for (monthKey, consumption) in consumptions {
                // If monthlyConsumptions[monthKey] exists, we add the consumption to the existing value, otherwise we set it as the initial value for this monthKey
                if let existing = monthlyConsumptions[monthKey] {
                    monthlyConsumptions[monthKey] = existing + consumption
                } else {
                    monthlyConsumptions[monthKey] = consumption
                }
            }
        }
        return monthlyConsumptions
    }
    
    class func classString() -> String {
        return NSStringFromClass(self)
    }
}

