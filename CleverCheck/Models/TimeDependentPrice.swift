//
//  TimeDependentPrice.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 09/10/2026.
//

import Foundation
import SwiftData

/// Represents a price that is only valid during a specific time period of the day. It can also be associated with a seasonal price.
/// If the entire day should be covered, the start time should be set to 00:00 and the end time to 23:59.
@Model
final class TimeDependentPrice: Identifiable, Equatable, Comparable {
    var id: UUID = UUID()
    var startHour: Int = 0
    var startMinute: Int = 0
    var endHour: Int = 23
    var endMinute: Int = 59
    var price: Cost = Cost(amount: 0.0)
    var seasonalPrice: SeasonalPrice?
    
    /// Returns the price converted to the user's selected currency. If conversion fails, returns the original amount.
    var converted: Cost {
        price.converted(to: UserSettings.shared.currencyIdentifier) ?? price
    }
    
    /// Initializes a new instance of the TimeDependentPrice class.
    /// - Parameters:
    ///   - startHour: The hour of the day when the price starts (0-23).
    ///   - startMinute: The minute of the day when the price starts (0-59).
    ///   - endHour: The hour of the day when the price ends (0-23).
    ///   - endMinute: The minute of the day when the price ends (0-59).
    ///   - price: The price for the time period.
    init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, price: Cost) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.price = price
    }
    
    static func == (lhs: TimeDependentPrice, rhs: TimeDependentPrice) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func < (lhs: TimeDependentPrice, rhs: TimeDependentPrice) -> Bool {
        if lhs.startHour != rhs.startHour {
            return lhs.startHour < rhs.startHour
        } else if lhs.startMinute != rhs.startMinute {
            return lhs.startMinute < rhs.startMinute
        } else if lhs.endHour != rhs.endHour {
            return lhs.endHour < rhs.endHour
        } else {
            return lhs.endMinute < rhs.endMinute
        }
    }
}
