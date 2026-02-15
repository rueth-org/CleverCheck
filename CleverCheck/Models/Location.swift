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
        let timeKey: String
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
            lhs.timeKey < rhs.timeKey
        }
        
        static func == (lhs: Location.Data, rhs: Location.Data) -> Bool {
            lhs.timeKey == rhs.timeKey
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
    
    func data(in timeBox: TimeBox) -> [Data] {
        // Build a cache key using essential inputs that influence the result
        let startTs = timeBox.timePeriod?.start.timeIntervalSince1970 ?? 0
        let endTs = timeBox.timePeriod?.end.timeIntervalSince1970 ?? 0
        let key = "loc:" + id.uuidString + "|res:\(timeBox.selectedResolution)|start:\(startTs)|end:\(endTs)|gross:\(UserSettings.shared.displayGrossPrices)|energyUnit:\(UserSettings.shared.energyUnit.symbol)"

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
        var grossPerConsumption: [[String: Double]] = []
        var netPerConsumption: [[String: Double]] = []
        var costPerConsumption: [[String: (gross: Double, net: Double)]] = []

        grossPerConsumption.reserveCapacity(homeConsumptions.count)
        netPerConsumption.reserveCapacity(homeConsumptions.count)
        costPerConsumption.reserveCapacity(homeConsumptions.count)

        for consumption in homeConsumptions {
            grossPerConsumption.append(consumption.consumptionPerMonth(includeIfIncludedElsewhere: false))
            netPerConsumption.append(consumption.netConsumptionPerMonth)
            costPerConsumption.append(consumption.totalCostPerMonth(isGross: UserSettings.shared.displayGrossPrices, useConsumptionFromRelatedChargingSessions: true))
        }

        // Step through the months and aggregate from precomputed maps
        let calendar = Calendar.current
        var currentDate = timePeriod.start
        while currentDate <= timePeriod.end {
            let monthKeyDisplay = timeBox.getKeyForDate(currentDate)
            let monthKeyGrouping = UserSettings.shared.groupingDateFormatter.string(from: currentDate)

            var grossConsumption: Double = 0.0
            var netConsumption: Double = 0.0
            var grossCost: Double = 0.0
            var netCost: Double = 0.0

            for idx in homeConsumptions.indices {
                grossConsumption += grossPerConsumption[idx][monthKeyGrouping] ?? 0.0
                netConsumption += netPerConsumption[idx][monthKeyGrouping] ?? 0.0
                grossCost += costPerConsumption[idx][monthKeyGrouping]?.gross ?? 0.0
                netCost += costPerConsumption[idx][monthKeyGrouping]?.net ?? 0.0
            }

            let deltaConsumption = grossConsumption - netConsumption
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
    
    func cost(in timeBox: TimeBox) -> (home: Cost, charging: Cost) {
        let homeConsumptions = homeConsumptions(in: timeBox)
        let allCost = homeConsumptions.map { $0.totalCost(isGross: UserSettings.shared.displayGrossPrices) }
        let gross = allCost.reduce(0.0) { $0 + $1.gross }
        let net = allCost.reduce(0.0) { $0 + $1.net }

        return (
            home: .init(amount: net),
            charging: .init(amount: gross - net)
        )
    }
    
    class func classString() -> String {
        return NSStringFromClass(self)
    }
}
