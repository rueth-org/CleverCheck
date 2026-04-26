//
//  PowerPrice.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 26/04/2026.
//

import Foundation

struct PowerPrice: Codable, Hashable {
    var timeUTC: Date
    var price: Cost
}
