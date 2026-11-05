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
struct PublicSeasonalPrice: Codable, Hashable {
    var name: String
    var groupName: String
    var groupCountryCode: String
    var startDate: Date
    var endDate: Date
    
    // The prices dictionary maps a double key (0.0-23.75) representing the hour of the day (in quarter hour steps) to a Cost object. The default price for hour 0 is set to 0.0.
    var prices: Dictionary<Double, Cost> = [0.0: Cost(amount: 0.0)]
    
    init(name: String, groupName: String, groupCountryCode: String, startDate: Date, endDate: Date, prices: Dictionary<Double, Cost>) {
        self.name = name
        self.groupName = groupName
        self.groupCountryCode = groupCountryCode
        self.startDate = startDate
        self.endDate = endDate
        self.prices = prices
    }
    
    func seasonalPriceGroup(context: ModelContext) -> SeasonalPriceGroup {
        SeasonalPriceGroup.getOrCreateSeasonalPriceGroup(name: groupName, countryCode: groupCountryCode, in: context)
    }
}

