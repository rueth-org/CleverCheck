//
//  UserSettings.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 23/11/2025.
//

import Foundation
import SwiftData

@Model
final class UserSettings {
    static let shared = UserSettings()
    
    var measurementSystem: Locale.MeasurementSystem = Locale.current.measurementSystem
    var currency: Locale.Currency = Locale.current.currency ?? .init("EUR")
    var vatRate: Double = 0.25
    var displayGrossPrices: Bool = true
    
    var distanceUnit: UnitLength {
        switch measurementSystem {
        case .metric:
            return .kilometers
        case .us, .uk:
            return .miles
        default:
            fatalError()
        }
    }
    
    var energyUnit: UnitEnergy {
        .kilowattHours
    }
    
    var currencyCode: String {
        currency.identifier
    }
    
    var groupingDateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        return dateFormatter
    }
    
    var displayDateFormat: Date.FormatStyle {
        Date.FormatStyle().year().month(.twoDigits).day(.twoDigits)
    }
    
    var displayDateFormatInSection: Date.FormatStyle {
        Date.FormatStyle().year().month(.wide)
    }
    
    private init() {
        // Empty on purpose
    }
    
    func precision(for amount: Double) -> Int {
        if amount < 1 {
            return 4
        } else if amount < 10 {
            return 3
        } else if amount < 100 {
            return 2
        } else if amount < 1000 {
            return 1
        } else {
            return 0
        }
    }
    
    func energyUnit(for symbol: String) -> UnitEnergy? {
        switch symbol {
        case "kWh":
            return .kilowattHours
        case "cal":
            return .calories
        case "J":
            return .joules
        case "kJ":
            return .kilojoules
        case "kCal":
            return .kilocalories
        default:
            return nil
        }
    }
}
