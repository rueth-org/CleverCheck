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
    enum SeasonalPriceError: Error {
        case noDates
        case noSeasonalPrices
        case noMatchingSeason(startDate: Date, endDate: Date)
        case noMatchingTime(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int)
        
        // Provide localized error descriptions by conforming to LocalizedError and returning
        // NSLocalizedString keys. Add translations in your Localizable.strings / .xcstrings files.
        var errorDescription: String {
            switch self {
            case .noDates:
                return NSLocalizedString("No dates provided for seasonal price.", comment: "")
            case .noSeasonalPrices:
                return NSLocalizedString("No seasonal prices available.", comment: "")
            case .noMatchingSeason(let startDate, let endDate):
                return NSLocalizedString("No matching seasonal price found for period from \(startDate.formatted()) to \(endDate.formatted())", comment: "")
            case .noMatchingTime(let startHour, let startMinute, let endHour, let endMinute):
                return NSLocalizedString("No matching time-dependent price found for period from \(startHour):\(startMinute) to \(endHour):\(endMinute)", comment: "")
            }
        }
    }
    
    var id: UUID = UUID()
    var startDate: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: Date()))!
    var endDate: Date = Calendar.current.date(byAdding: DateComponents(year: 1, day: -1), to: Calendar.current.date(from: Calendar.current.dateComponents([.year], from: Date()))!)!
    var priceElement: PriceElement?
    
    @Relationship(deleteRule: .cascade, inverse: \TimeDependentPrice.seasonalPrice)
    var prices: [TimeDependentPrice]?
    
    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
    
    func getConvertedPrice(hour: Int, minute: Int) -> Cost? {
        guard let prices = prices else { return nil }
        for price in prices {
            if price.startHour < hour, hour < price.endHour {
                return price.converted
            } else if hour == price.endHour, minute <= price.endMinute {
                return price.converted
            } else if hour == price.startHour, price.startMinute <= minute {
                return price.converted
            }
        }
        return nil
    }
    
    static func == (lhs: SeasonalPrice, rhs: SeasonalPrice) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func < (lhs: SeasonalPrice, rhs: SeasonalPrice) -> Bool {
        return lhs.startDate < rhs.startDate
    }
}

