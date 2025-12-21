//
//  UserSettings.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 23/11/2025.
//

import Foundation
import SwiftUI
import SwiftData

final class UserSettings {
    static let shared = UserSettings()
    
    @AppStorage("measurementSystem") var measurementSystem: String = Locale.current.measurementSystem.identifier
    @AppStorage("currencyIdentifier") var currencyIdentifier: String = Locale.current.currency?.identifier ?? "EUR"
    @AppStorage("vatRate") var vatRate: Double = 0.25
    @AppStorage("displayGrossPrices") var displayGrossPrices: Bool = true
    
    var distanceUnit: UnitLength {
        switch measurementSystem {
        case Locale.MeasurementSystem.metric.identifier:
            return .kilometers
        case Locale.MeasurementSystem.us.identifier, Locale.MeasurementSystem.uk.identifier:
            return .miles
        default:
            fatalError()
        }
    }
    
    var energyUnit: UnitEnergy {
        .kilowattHours
    }
    
    var powerUnit: UnitPower {
        .kilowatts
    }
    
    var currency: Locale.Currency {
        Locale.Currency.init(currencyIdentifier)
    }
    
    var groupingDateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        return dateFormatter
    }
    
    var shortDateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
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
