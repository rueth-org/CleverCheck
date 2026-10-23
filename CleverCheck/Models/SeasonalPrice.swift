//
//  SeasonalPrice.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 09/10/2026.
//

import Foundation
import SwiftData

/// Represents a seasonal price with a start and end date, and associated time-dependent prices.
/// Default start and end dates are beginning end end of the current year.
@Model
final class SeasonalPrice: Identifiable, Equatable, Comparable {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: Date()))!
    var endDate: Date = Calendar.current.date(byAdding: DateComponents(year: 1, day: -1), to: Calendar.current.date(from: Calendar.current.dateComponents([.year], from: Date()))!)!
    
    @Relationship(deleteRule: .nullify, inverse: \PriceElement.seasonalPrice)
    var priceElements: [PriceElement]?
    
    // The prices dictionary maps a double key (0.0-23.75) representing the hour of the day (in quarter hour steps) to a Cost object. The default price for hour 0 is set to 0.0.
    var prices: Dictionary<Double, Cost> = [0.0: Cost(amount: 0.0)]
    
    init(name: String, startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
    
    /// Inserts a price for a given hour and minute.
    /// - Parameters:
    ///   - price: The price to insert.
    ///   - hour: The hour of the day (0-23).
    ///   - minute: The minute of the hour (0-59).
    func insertPrice(_ price: Cost, at hour: Int, minute: Int) {
        let hourDouble = Double(hour) + Double(minute) / 60.0
        prices[hourDouble] = price
    }
    
    /// Returns the price for a given hour and minute, converted to the user's selected currency. If no matching price is found, returns the default price for hour 0.
    /// - Parameters:
    ///   - hour: The hour of the day (0-23).
    ///   - minute: The minute of the hour (0-59).
    /// - Returns: The price for the given time, converted to the user's selected currency.
    func getConvertedPrice(hour: Int, minute: Int) -> Cost {
        // Convert hour and minute into a double
        let hourDouble = Double(hour) + Double(minute) / 60.0
        
        let sortedTimes = prices.keys.sorted()
        for time in sortedTimes.reversed() {
            if hourDouble >= time {
                return prices[time]!.converted(to: UserSettings.shared.currencyIdentifier) ?? prices[time]!
            }
        }
        return prices[0.0]!.converted(to: UserSettings.shared.currencyIdentifier) ?? prices[0.0]!
    }
    
    static func == (lhs: SeasonalPrice, rhs: SeasonalPrice) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func < (lhs: SeasonalPrice, rhs: SeasonalPrice) -> Bool {
        return lhs.startDate < rhs.startDate
    }
}

