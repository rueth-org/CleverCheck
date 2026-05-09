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
    var timeZone: TimeZone
    var resolutionMinutes: Int
    var pricePerKWh: Cost
    
    var timeLocal: Date {
        let secondsFromUTC = TimeInterval(timeZone.secondsFromGMT(for: timeUTC))
        return Date(timeInterval: secondsFromUTC, since: timeUTC)
    }
    
    var granularity: Calendar.Component {
        switch resolutionMinutes {
        case 60:
            return .hour
        case 15:
            return .quarter
        default:
            return .minute
        }
    }
    
    init(serviceName: String, region: String, timeUTC: Date, timeZone: TimeZone = .current, resolutionMinutes: Int, pricePerKWh: Cost) {
        self.serviceName = serviceName
        self.region = region
        self.timeUTC = timeUTC
        self.timeZone = timeZone
        self.resolutionMinutes = resolutionMinutes
        self.pricePerKWh = pricePerKWh
    }
}
