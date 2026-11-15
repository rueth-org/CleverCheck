//
//  PowerPrice.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 26/04/2026.
//

import Foundation

enum PowerPriceGranularity: String, Codable {
    init?(rawValue: String) {
        switch rawValue {
        case "minute":
            self = .minute
        case "quarter":
            self = .quarter
        case "hour":
            self = .hour
        default:
            return nil
        }
    }
    
    init?(resolutionMinutes: Int) {
        switch resolutionMinutes {
        case 1: self = .minute
        case 15: self = .quarter
        case 60: self = .hour
        default: return nil
        }
    }
    
    var rawValue: String {
        switch self {
        case .minute:
            return "minute"
        case .quarter:
            return "quarter"
        case .hour:
            return "hour"
        }
    }
    
    var resolutionMinutes: Int {
        switch self {
        case .minute:
            return 1
        case .quarter:
            return 15
        case .hour:
            return 60
        }
    }
    
    var granularity: Calendar.Component {
        switch self {
        case .minute:
            return .minute
        case .quarter:
            return .quarter
        case .hour:
            return .hour
        }
    }
    
    case minute
    case quarter
    case hour
}

struct PowerPrice: Codable, Hashable {
    var serviceName: String
    var region: String
    var timeUTC: Date
    var timeZone: TimeZone
    var granularity: PowerPriceGranularity
    var pricePerKWh: Cost
    
    var timeLocal: Date {
        let secondsFromUTC = TimeInterval(timeZone.secondsFromGMT(for: timeUTC))
        return Date(timeInterval: secondsFromUTC, since: timeUTC)
    }
    
    init(serviceName: String, region: String, timeUTC: Date, timeZone: TimeZone = .current, granularity: PowerPriceGranularity, pricePerKWh: Cost) {
        self.serviceName = serviceName
        self.region = region
        self.timeUTC = timeUTC
        self.timeZone = timeZone
        self.granularity = granularity
        self.pricePerKWh = pricePerKWh
    }
}
