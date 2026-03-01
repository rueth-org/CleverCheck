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
        case homeConsumption = "Home consumption"
        case charging = "Charging"
        
        func color() -> DisplayColor {
            switch self {
            case .homeConsumption:
                return .blue
            case .charging:
                return .green
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
        var grossConsumptionPerMonth: [[String: Double]] = []
        var netConsumptionPerMonth: [[String: Double]] = []
        var costPerMonth: [[String: (gross: Cost, net: Cost)]] = []

        grossConsumptionPerMonth.reserveCapacity(homeConsumptions.count)
        netConsumptionPerMonth.reserveCapacity(homeConsumptions.count)
        costPerMonth.reserveCapacity(homeConsumptions.count)

        for consumption in homeConsumptions {
            grossConsumptionPerMonth.append(consumption.consumptionPerMonth(includeIfIncludedElsewhere: false, useRelatedConsumptions: useRelatedConsumption))
            netConsumptionPerMonth.append(consumption.netConsumptionPerMonth(useRelatedConsumptions: useRelatedConsumption))
            costPerMonth.append(consumption.totalCostPerMonth(isGross: UserSettings.shared.displayGrossPrices, useRelatedConsumptions: useRelatedConsumption))
        }
        
        // Get the refunded sessions related to this location in the given time period
        let refundedPerMonth = refundedPerMonth(in: timeBox, modelContext: modelContext)
        
        // TODO: Also consider the charged amount from home consumption type plans (e.g., EWII)
        
        // Step through the months and aggregate from precomputed maps
        let calendar = Calendar.current
        var currentDate = timePeriod.start
        while currentDate <= timePeriod.end {
            let monthKeyDisplay = timeBox.getKeyForDate(currentDate)
            let monthKeyGrouping = UserSettings.shared.groupingDateFormatter.string(from: currentDate)

            var grossConsumption: Double = 0.0
            var netConsumption: Double = 0.0
            var grossCost: Cost = .init(amount: 0.0)
            var netCost: Cost = .init(amount: 0.0)

            for idx in homeConsumptions.indices {
                grossConsumption += grossConsumptionPerMonth[idx][monthKeyGrouping] ?? 0.0
                netConsumption += netConsumptionPerMonth[idx][monthKeyGrouping] ?? 0.0
                grossCost += costPerMonth[idx][monthKeyGrouping]?.gross ?? .init(amount: 0.0)
                netCost += costPerMonth[idx][monthKeyGrouping]?.net ?? .init(amount: 0.0)
            }

            var deltaConsumption = grossConsumption - netConsumption
            let deltaCost = grossCost - netCost
            
            // If there is a refunded session in this month, subtract its consumption and cost from the home consumption and add the consumption to the charging part, since it is a refunded charging session that is included in the home consumption via the "includedInOtherPlan" relation. The refunded cost is not added to delta cost, as it's paid for by the refunding plan.
            if let refundedData = refundedPerMonth[monthKeyGrouping] {
                netConsumption -= refundedData.consumption.value
                netCost += refundedData.cost // refundedData.cost is a negative value, so we add it to netCost to reduce the total cost
                deltaConsumption += refundedData.consumption.value
            }

            // Create home consumption data set
            result.append(Data(
                groupingKey: monthKeyGrouping,
                displayKey: monthKeyDisplay,
                dataType: .homeConsumption,
                consumption: .init(value: netConsumption, unit: UserSettings.shared.energyUnit),
                cost: netCost
            ))

            // Create charging data set
            result.append(Data(
                groupingKey: monthKeyGrouping,
                displayKey: monthKeyDisplay,
                dataType: .charging,
                consumption: .init(value: deltaConsumption, unit: UserSettings.shared.energyUnit),
                cost: deltaCost
            ))

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
    
    /// Returns the cost for the given time box. Only considers home consumptions. The charging cost is calculated as the difference between gross and net cost of the home consumptions, so it also includes costs of related charging sessions that are included in the home consumption via the "includedInOtherPlan" relation.
    /// - Parameter timeBox: The time box to limit the home consumptions to.
    /// - Parameter useRelatedConsumptions: Whether to consider the consumption from related charging sessions that are included in the home consumption when calculating the cost. If true, the cost will be calculated based on the total consumption of the home consumption. If false, the cost will be calculated based on the consumption of the home consumption that is not included in related charging sessions. This parameter can be used to get a more accurate calculation of the home consumption cost when there are related charging sessions that are included in the home consumption.
    /// - Returns: A tuple containing the home cost and the charging cost.
    func cost(in timeBox: TimeBox, useRelatedConsumptions: Bool) -> (home: Cost, charging: Cost) {
        let homeConsumptions = homeConsumptions(in: timeBox)
        let allCost = homeConsumptions.map { $0.totalCost(isGross: UserSettings.shared.displayGrossPrices, useRelatedConsumptions: useRelatedConsumptions) }
        let gross = allCost.reduce(.init(amount: 0.0)) { $0 + $1.gross }
        let net = allCost.reduce(.init(amount: 0.0)) { $0 + $1.net }

        return (
            home: net,
            charging: gross - net
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
            monthlyData[monthKey, default: (consumption: 0.0, cost: 0.0)].consumption += session.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value
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

