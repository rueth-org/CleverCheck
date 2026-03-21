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
    struct Data: Identifiable, Comparable, GraphItem {
        let id = UUID()
        let groupingKey: String
        let displayKey: String
        let dataType: HomeConsumption.ConsumptionType
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
        if !UserSettings.shared.disableCache, let cached = Location.cachedData(forKey: key) {
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
        var homeConsumptionPerMonth: [[String: Measurement<UnitEnergy>]] = []
        var homeCostPerMonth: [[String: Cost]] = []
        var homeRefundedConsumptionPerMonth: [[String: Measurement<UnitEnergy>]] = []
        var homeRefundedCostPerMonth: [[String: Cost]] = []
        var homeDiscountConsumptionPerMonth: [[String: Measurement<UnitEnergy>]] = []
        var homeDiscountCostPerMonth: [[String: Cost]] = []
        var chargingConsumptionPerMonth: [[String: Measurement<UnitEnergy>]] = []
        var chargingCostPerMonth: [[String: Cost]] = []
        var chargingRefundedConsumptionPerMonth: [[String: Measurement<UnitEnergy>]] = []
        var chargingRefundedCostPerMonth: [[String: Cost]] = []
        var chargingDiscountConsumptionPerMonth: [[String: Measurement<UnitEnergy>]] = []
        var chargingDiscountCostPerMonth: [[String: Cost]] = []

        for homeConsumption in homeConsumptions {
            let consumption = homeConsumption.consumptionPerMonth(useRelatedConsumptions: useRelatedConsumption)
            let cost = homeConsumption.totalCostPerMonth(includingVAT: UserSettings.shared.displayGrossPrices, useRelatedConsumptions: useRelatedConsumption)
            
            debugPrint("Processing home consumption \(homeConsumption.name) (\(homeConsumption.consumptionType.description)) - period: \(homeConsumption.validFrom) to \(homeConsumption.validUntil) - consumption: \(consumption), cost: \(cost)")
            
            switch homeConsumption.consumptionType {
            case .total:
                totalConsumptionPerMonth.append(consumption)
                totalCostPerMonth.append(cost)
            case .home:
                homeConsumptionPerMonth.append(consumption)
                homeCostPerMonth.append(cost)
            case .homeRefunded:
                homeRefundedConsumptionPerMonth.append(consumption)
                homeRefundedCostPerMonth.append(cost)
            case .homeDiscount:
                homeDiscountConsumptionPerMonth.append(consumption)
                homeDiscountCostPerMonth.append(cost)
            case .charging:
                chargingConsumptionPerMonth.append(consumption)
                chargingCostPerMonth.append(cost)
            case .chargingRefunded:
                chargingRefundedConsumptionPerMonth.append(consumption)
                chargingRefundedCostPerMonth.append(cost)
            case .chargingDiscount:
                chargingDiscountConsumptionPerMonth.append(consumption)
                chargingDiscountCostPerMonth.append(cost)
            }
        }
        
        // Get the refunded sessions related to this location in the given time period
        let refundedChargingPerMonth = refundedChargingPerMonth(in: timeBox, modelContext: modelContext)
        
        // Get the related charging consumptions for this location in the given time period, excluding refunded sessions
        let relatedChargingConsumptionsPerMonth = relatedChargingConsumptionsPerMonth(in: timeBox)
        
        // Step through the months and aggregate from precomputed maps
        let calendar = Calendar.current
        var currentDate = timePeriod.start
        while currentDate <= timePeriod.end {
            let monthKeys = timeBox.getKeysForDate(currentDate)
            
            // Sum up the total consumption and cost for this month, which is the sum of totalConsumption, homeConsumption and charging
            // Separately sum up the home and charging consumption and cost for this month
            var totalConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var totalCost: Cost = .init(amount: 0.0)
            var chargingConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var chargingCost: Cost = .init(amount: 0.0)
            
            for idx in totalConsumptionPerMonth.indices {
                totalConsumption = totalConsumption + (totalConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
                totalCost += totalCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            // Add home consumption to total consumption
            for idx in homeConsumptionPerMonth.indices {
                totalConsumption = totalConsumption + (homeConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
                totalCost += homeCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            for idx in chargingConsumptionPerMonth.indices {
                let consumption = (chargingConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
                let cost = chargingCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
                totalConsumption = totalConsumption + consumption
                totalCost += cost
                chargingConsumption = chargingConsumption + consumption
                chargingCost += cost
            }
            
            // Sum up the refunded consumption and cost for this month
            var homeRefundedConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var homeRefundedCost: Cost = .init(amount: 0.0)
            for idx in homeRefundedConsumptionPerMonth.indices {
                homeRefundedConsumption = homeRefundedConsumption + (homeRefundedConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
                homeRefundedCost += homeRefundedCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // Sum up the discounted consumption and cost for this month
            var homeDiscountConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var homeDiscountCost: Cost = .init(amount: 0.0)
            for idx in homeDiscountConsumptionPerMonth.indices {
                homeDiscountConsumption = homeDiscountConsumption + (homeDiscountConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
                homeDiscountCost += homeDiscountCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // Sum up the charging refunded consumption and cost for this month
            var chargingRefundedConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var chargingRefundedCost: Cost = .init(amount: 0.0)
            for idx in chargingRefundedConsumptionPerMonth.indices {
                chargingRefundedConsumption = chargingRefundedConsumption + (chargingRefundedConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
                chargingRefundedCost += chargingRefundedCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // Sum up the charging discounted consumption and cost for this month
            var chargingDiscountConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var chargingDiscountCost: Cost = .init(amount: 0.0)
            for idx in chargingDiscountConsumptionPerMonth.indices {
                chargingDiscountConsumption = chargingDiscountConsumption + (chargingDiscountConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
                chargingDiscountCost += chargingDiscountCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // If there is a refunded session in this month, add them to the refunded part
            if let refundedChargingData = refundedChargingPerMonth[monthKeys.grouping] {
                chargingRefundedConsumption = chargingRefundedConsumption + refundedChargingData.consumption
                chargingRefundedCost += refundedChargingData.cost
            }
            
            // Initialize the total consumption minus all refunding consumptions
            let totalConsumptionInclRefunds = totalConsumption - chargingRefundedConsumption - homeRefundedConsumption
            
            // Initialize the total cost minus all refunding costs - as the refunding cost are negative values, we actually add them to get the cost including refunds
            let totalCostInclRefunds = totalCost + chargingRefundedCost + homeRefundedCost
            
            // Initialize home consumption with total consumption incl. refunds
            var homeConsumption = totalConsumptionInclRefunds
            var homeCost = totalCostInclRefunds
            
            // If there are charging sessions from related charging cost plans, add them to the charging part
            if let relatedChargingConsumption = relatedChargingConsumptionsPerMonth[monthKeys.grouping] {
                // Determine the cost portion of home cost incl. refunds related to charging
                let chargingCostPortion = relatedChargingConsumption.converted(to: UserSettings.shared.energyUnit).value / totalConsumptionInclRefunds.converted(to: UserSettings.shared.energyUnit).value
                
                // Add the consumption from the related sessions to the charging consumption and substract it from the home consumption
                chargingConsumption = chargingConsumption + relatedChargingConsumption
                homeConsumption = homeConsumption - relatedChargingConsumption
                
                // Subtract the related charging cost portion from the home cost and add it to the charging cost
                chargingCost += Cost(amount: chargingCostPortion * totalCostInclRefunds.amount)
                homeCost -= Cost(amount: chargingCostPortion * totalCostInclRefunds.amount)
            }
            
            // Subtract charging discount from charging cost (the discount is negative, therefore we add it)
            chargingCost += chargingDiscountCost
            
            // Substract home discount from home cost (the discount is negative, therefore we add it)
            homeCost += homeDiscountCost

            // Create total consumption data set
            if totalConsumption.value != 0.0 && totalCost.amount != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .total,
                    consumption: totalConsumption,
                    cost: totalCost
                ))
            }

            // Create home consumption data set
            if homeConsumption.value != 0.0 && homeCost.amount != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .home,
                    consumption: homeConsumption,
                    cost: homeCost
                ))
            }
            
            // Create home discount data set (to get a positive value, we use the negative of the home discount cost, which is a negative value)
            if homeDiscountConsumption.value != 0.0 && homeDiscountCost.amount != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .homeDiscount,
                    consumption: homeDiscountConsumption,
                    cost: -homeDiscountCost
                ))
            }
            
            // Create home refunded data set (to get a positive value, we use the negative of the home refunded cost, which is a negative value)
            if homeRefundedConsumption.value != 0.0 && homeRefundedCost.amount != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .homeRefunded,
                    consumption: homeRefundedConsumption,
                    cost: -homeRefundedCost
                ))
            }

            // Create home charging data set
            if chargingConsumption.value != 0.0 && chargingCost.amount != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .charging,
                    consumption: chargingConsumption,
                    cost: chargingCost
                ))
            }
            
            // Create charging discount data set (to get a positive value, we use the negative of the charging discount cost, which is a negative value)
            if chargingDiscountConsumption.value != 0.0 && chargingDiscountCost.amount != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .chargingDiscount,
                    consumption: chargingDiscountConsumption,
                    cost: -chargingDiscountCost
                ))
            }
            
            // Create charging refunded data set (to get a positive value, we use the negative of the charging refunded cost, which is a negative value)
            if chargingRefundedConsumption.value != 0.0 && chargingRefundedCost.amount != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .chargingRefunded,
                    consumption: chargingRefundedConsumption,
                    cost: -chargingRefundedCost
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
    private func refundedChargingPerMonth(in timeBox: TimeBox, modelContext: ModelContext) -> [String: (consumption: Measurement<UnitEnergy>, cost: Cost)] {
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
    
    private func relatedChargingConsumptionsPerMonth(in timeBox: TimeBox) -> [String: Measurement<UnitEnergy>] {
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

extension HomeConsumption.ConsumptionType {
    func color() -> DisplayColor {
        switch self {
        case .total: return .gray
        case .home: return .red
        case .homeDiscount: return .purple
        case .homeRefunded: return .indigo
        case .charging: return .green
        case .chargingDiscount: return .orange
        case .chargingRefunded: return .red
        }
    }
}

