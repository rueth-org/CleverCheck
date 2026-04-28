//
//  PowerPrice.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 26/04/2026.
//

import Foundation

struct PowerPrice: Codable, Hashable {
    var serviceName: String
    var region: String
    var timeUTC: Date
    var timeLocal: Date?
    var resolutionMinutes: Int
    var price: Cost
}
