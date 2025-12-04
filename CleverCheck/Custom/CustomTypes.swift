//
//  Cost.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 29/11/2025.
//

import Foundation

struct Cost: Codable {
    var amount: Double
    var currency: Locale.Currency = UserSettings.shared.currency
}
