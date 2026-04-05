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
        var refundingOtherPlanConsumptionPerMonth: [[String: Measurement<UnitEnergy>]] = []
        var refundingOtherPlanCostPerMonth: [[String: Cost]] = []

        // Get the refunded sessions related to this location in the given time period
        let refundedChargingPerMonth = refundedChargingPerMonth(in: timeBox, modelContext: modelContext)
        
        for homeConsumption in homeConsumptions {
            let refundedForConsumption = refunded(refundedChargingPerMonth, from: homeConsumption.validFrom, to: homeConsumption.validUntil)
            let consumption = homeConsumption.consumptionPerMonth(useRelatedConsumptions: UserSettings.shared.useRelatedConsumptions, reduceTotalBy: refundedForConsumption.consumption)
            let cost = homeConsumption.costPerMonth(includingVAT: UserSettings.shared.displayGrossPrices, useRelatedConsumptions: UserSettings.shared.useRelatedConsumptions, reduceTotalBy: refundedForConsumption)
            
            debugPrint("Processing home consumption \(homeConsumption.name) (\(homeConsumption.consumptionType.description)) - period: \(homeConsumption.validFrom) to \(homeConsumption.validUntil)")
            
            switch homeConsumption.consumptionType {
            case .total, .home, .charging:
                for monthKey in consumption.keys {
                    homeConsumptionPerMonth.append([monthKey: consumption[monthKey]!.home])
                    chargingConsumptionPerMonth.append([monthKey: consumption[monthKey]!.charging])
                }
                for monthKey in cost.keys {
                    homeCostPerMonth.append([monthKey: cost[monthKey]!.home])
                    chargingCostPerMonth.append([monthKey: cost[monthKey]!.charging])
                }
            case .homeRefunded:
                for monthKey in consumption.keys {
                    homeRefundedConsumptionPerMonth.append([monthKey: consumption[monthKey]!.home])
                }
                for monthKey in cost.keys {
                    homeRefundedCostPerMonth.append([monthKey: cost[monthKey]!.home])
                }
            case .homeDiscount:
                for monthKey in consumption.keys {
                    homeDiscountConsumptionPerMonth.append([monthKey: consumption[monthKey]!.home])
                }
                for monthKey in cost.keys {
                    homeDiscountCostPerMonth.append([monthKey: cost[monthKey]!.home])
                }
            case .chargingRefunded:
                for monthKey in consumption.keys {
                    chargingRefundedConsumptionPerMonth.append([monthKey: consumption[monthKey]!.charging])
                }
                for monthKey in cost.keys {
                    chargingRefundedCostPerMonth.append([monthKey: cost[monthKey]!.charging])
                }
            case .chargingDiscount:
                for monthKey in consumption.keys {
                    chargingDiscountConsumptionPerMonth.append([monthKey: consumption[monthKey]!.charging])
                }
                for monthKey in cost.keys {
                    chargingDiscountCostPerMonth.append([monthKey: cost[monthKey]!.charging])
                }
            case .refundingOtherPlan:
                for monthKey in consumption.keys {
                    refundingOtherPlanConsumptionPerMonth.append([monthKey: consumption[monthKey]!.charging])
                }
                for monthKey in cost.keys {
                    refundingOtherPlanCostPerMonth.append([monthKey: cost[monthKey]!.charging])
                }
            }
        }
        
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
            
            // Add home consumption to total consumption
            for idx in homeConsumptionPerMonth.indices {
                totalConsumption = totalConsumption + (homeConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
            }
            
            // Add home cost to total cost
            for idx in homeCostPerMonth.indices {
                totalCost += homeCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // Add charging consumption to total consumption and separately to charging consumption
            for idx in chargingConsumptionPerMonth.indices {
                let consumption = (chargingConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
                totalConsumption = totalConsumption + consumption
                chargingConsumption = chargingConsumption + consumption
            }
            
            // Add charging cost to total cost and separately to charging cost
            for idx in chargingConsumptionPerMonth.indices {
                let cost = chargingCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
                totalCost += cost
                chargingCost += cost
            }
            
            // If there is a refunded session in this month, add them to the total and the refunded part
            var chargingRefundedConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var chargingRefundedCost: Cost = .init(amount: 0.0)
            if let refundedChargingData = refundedChargingPerMonth[monthKeys.grouping] {
                totalConsumption = totalConsumption + refundedChargingData.consumption
                totalCost -= refundedChargingData.cost // refunded charging cost is negative, therefore we need to subtract to add it to the total cost
                chargingRefundedConsumption = chargingRefundedConsumption + refundedChargingData.consumption
                chargingRefundedCost += refundedChargingData.cost
            }
            
            // If there is refunding for other plans in this month, add it to the refundingOtherPlan part
            var refundingOtherPlanConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var refundingOtherPlanCost: Cost = .init(amount: 0.0)
            for idx in refundingOtherPlanConsumptionPerMonth.indices {
                refundingOtherPlanConsumption = refundingOtherPlanConsumption + (refundingOtherPlanConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
            }
            for idx in refundingOtherPlanCostPerMonth.indices {
                refundingOtherPlanCost += refundingOtherPlanCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // If we don't have have any total values (e.g., because no invoice was entered yet for the month), we can skip the month, as there is no valid data to show
            if totalConsumption.value == 0.0 && totalCost.amount == 0.0 {
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
                continue
            }
            
            // Sum up the refunded consumption and cost for this month
            var homeRefundedConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var homeRefundedCost: Cost = .init(amount: 0.0)
            for idx in homeRefundedConsumptionPerMonth.indices {
                homeRefundedConsumption = homeRefundedConsumption + (homeRefundedConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
            }
            for idx in homeRefundedCostPerMonth.indices {
                homeRefundedCost += homeRefundedCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // Sum up the discounted consumption and cost for this month
            var homeDiscountConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var homeDiscountCost: Cost = .init(amount: 0.0)
            for idx in homeDiscountConsumptionPerMonth.indices {
                homeDiscountConsumption = homeDiscountConsumption + (homeDiscountConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
            }
            for idx in homeDiscountCostPerMonth.indices {
                homeDiscountCost += homeDiscountCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // Sum up the charging refunded consumption and cost for this month
            for idx in chargingRefundedConsumptionPerMonth.indices {
                chargingRefundedConsumption = chargingRefundedConsumption + (chargingRefundedConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
            }
            for idx in chargingRefundedCostPerMonth.indices {
                chargingRefundedCost += chargingRefundedCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // Sum up the charging discounted consumption and cost for this month
            var chargingDiscountConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
            var chargingDiscountCost: Cost = .init(amount: 0.0)
            for idx in chargingDiscountConsumptionPerMonth.indices {
                chargingDiscountConsumption = chargingDiscountConsumption + (chargingDiscountConsumptionPerMonth[idx][monthKeys.grouping] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit))
            }
            for idx in chargingDiscountCostPerMonth.indices {
                chargingDiscountCost += chargingDiscountCostPerMonth[idx][monthKeys.grouping] ?? .init(amount: 0.0)
            }
            
            // Initialize the total consumption minus all refunding consumptions
            let totalConsumptionInclRefunds = totalConsumption - chargingRefundedConsumption - homeRefundedConsumption - refundingOtherPlanConsumption
            
            // Initialize the total cost minus all refunding costs - as the refunding cost are negative values, we actually add them to get the cost including refunds
            let totalCostInclRefunds = totalCost + chargingRefundedCost + homeRefundedCost + refundingOtherPlanCost
            
            // Initialize home consumption with total consumption incl. refunds
            var homeConsumption = totalConsumptionInclRefunds
            var homeCost = totalCostInclRefunds
            
            // Subtract charging discount from charging cost (the discount is negative, therefore we add it)
            chargingCost += chargingDiscountCost
            
            // Subtract charging from home
            homeConsumption = homeConsumption - chargingConsumption
            homeCost -= chargingCost
            
            // Subtract home discount from home cost (the discount is negative, therefore we add it)
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
            
            // Create refunding other plans data set (to get a positive value, we use the negative of the refunding other plan cost, which is a negative value)
            if refundingOtherPlanConsumption.value != 0.0 && refundingOtherPlanCost.amount != 0.0 {
                result.append(Data(
                    groupingKey: monthKeys.grouping,
                    displayKey: monthKeys.display,
                    dataType: .refundingOtherPlan,
                    consumption: refundingOtherPlanConsumption,
                    cost: -refundingOtherPlanCost
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
    
    /// Calculates the refunded consumption and cost for a given date range. Only considers the refunded charging sessions that are related to this location via their charger and that fall within the given date range. As we only have the refunded consumption and cost per month available, we need to prorate the values for the specific date range of the home consumption to get a more accurate estimate of the refunded consumption and cost related to this home consumption.
    /// - Parameters:
    ///   - refundedChargingPerMonth: A dictionary with the refunded consumption and cost per month for the charging sessions related to this location. The key is the month formatted as string, the value is a tuple with the refunded consumption and cost for this month.
    ///   - from: The start date of the date range to consider for the prorating. Should be the validFrom date of the home consumption.
    ///   - to: The end date of the date range to consider for the prorating. Should be the validUntil date of the home consumption.
    /// - Returns: A tuple with the total refunded consumption and cost for the given date range.
    private func refunded(_ refundedChargingPerMonth: [String: (consumption: Measurement<UnitEnergy>, cost: Cost)], from: Date, to: Date) -> (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let calendar = Calendar.current
        var totalRefundedConsumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: UserSettings.shared.energyUnit)
        var totalRefundedCost: Cost = .init(amount: 0.0)

        // Iterate over the refundedChargingPerMonth dictionary and sum up the values within the specified date range
        for (monthKey, data) in refundedChargingPerMonth {
            if let monthDate = UserSettings.shared.groupingDateFormatter.date(from: monthKey),
               monthDate >= from && monthDate <= to {
                // Get the number of days in the month to calculate the daily average, which we can then multiply with the number of days in the home consumption period that fall within the month to get a more accurate estimate for the refunded consumption and cost related to this home consumption
                let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: monthDate)!.count
                let dailyRefundedConsumption = data.consumption.converted(to: UserSettings.shared.energyUnit).value / Double(numberOfDaysInMonth)
                let dailyRefundedCost = (data.cost.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0) / Double(numberOfDaysInMonth)
                let daysInHomeConsumption = calendar.dateComponents([.day], from: max(monthDate, from), to: min(calendar.date(byAdding: .month, value: 1, to: monthDate)!, to)).day! + 1
                let proratedRefundedConsumption = dailyRefundedConsumption * Double(daysInHomeConsumption)
                let proratedRefundedCost = dailyRefundedCost * Double(daysInHomeConsumption)
                
                
                totalRefundedConsumption = totalRefundedConsumption + Measurement(value: proratedRefundedConsumption, unit: UserSettings.shared.energyUnit)
                totalRefundedCost += Cost(amount: proratedRefundedCost)
            }
        }

        return (totalRefundedConsumption, totalRefundedCost)
    }
    
    /// Returns the refunded consumption and cost for the given time box. Only considers charging sessions of type .refunded that are related to this location via their charger.
    /// - Parameters:
    ///   - timeBox: The time box to limit the charging sessions to.
    ///   - modelContext: The model context to fetch data from.
    /// - Returns: A tuple containing the refunded consumption and refunded cost.
    private func refunded(in timeBox: TimeBox, modelContext: ModelContext) -> (consumption: Measurement<UnitEnergy>, cost: Cost) {
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
        
        guard !allRelatedPlans.isEmpty else { return [:] }
        
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
    
    class func classString() -> String {
        return NSStringFromClass(self)
    }
}

extension HomeConsumption.ConsumptionType {
    func color() -> DisplayColor {
        switch self {
        case .total: return .gray
        case .home: return .blue
        case .homeDiscount: return .purple
        case .homeRefunded: return .indigo
        case .charging: return .green
        case .chargingDiscount: return .orange
        case .chargingRefunded: return .red
        case .refundingOtherPlan: return .teal
        }
    }
}

