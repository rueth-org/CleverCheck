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
    @AppStorage("energyUnitSymbol") var energyUnitSymbol: String = "kWh"
    @AppStorage("powerUnitSymbol") var powerUnitSymbol: String = "kW"
    @AppStorage("energyOverDistance") var energyOverDistance: Bool = true
    @AppStorage("distanceMultiplier") var distanceMultiplier: Int = 100
    @AppStorage("vatRate") var vatRate: Double = 0.25
    @AppStorage("displayGrossPrices") var displayGrossPrices: Bool = true
    @AppStorage("referenceSOC") var referenceSOC: Double = 0.8
    @AppStorage("selectedCarId") var selectedCarId: String?
    @AppStorage("selectedLocationId") var selectedLocationId: String?
    
    // TODO make Show Archived Cars/Plans... persistent
    
    var consumptionUnitSymbol: String {
        energyOverDistance ? "\(energyUnit.symbol)/\(distanceMultiplier != 1 ? String(distanceMultiplier) : "")\(distanceUnit.symbol)" : "\(distanceUnit.symbol)/\(energyUnit.symbol)"
    }
    
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
    
    /// Returns the energy unit derived from the user setting for energy unit symbol, defaults to kWh
    var energyUnit: UnitEnergy {
        if let unit = energyUnit(for: energyUnitSymbol) {
            return unit
        } else {
            return .kilowattHours
        }
    }
    
    /// Returns the power unit derived from the user setting for power unit symbol, defaults to kW
    var powerUnit: UnitPower {
        if let unit = powerUnit(for: powerUnitSymbol) {
            return unit
        } else {
            return .kilowatts
        }
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
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyy/MM/dd")
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
    
    func format(_ value: Double, withSignificantDigits: Int) -> String {
        let style = Decimal.FormatStyle(locale: Locale.current)
            .rounded(rule: .toNearestOrAwayFromZero)
            .precision(.significantDigits(1...withSignificantDigits))
        return style.format(Decimal(value))
    }
    
    func formatAsCurrencyNoSymbol(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.minimumFractionDigits = value < 10 ? 2 : 0
        formatter.maximumFractionDigits = value < 10 ? 2 : 0
        return formatter.string(from: NSNumber(value: value)) ?? "-"
    }
    
    func energyUnit(for symbol: String) -> UnitEnergy? {
        switch symbol {
        case "kWh": return .kilowattHours
        case "cal": return .calories
        case "J": return .joules
        case "kJ": return .kilojoules
        case "kCal": return .kilocalories
        default: return nil
        }
    }
    
    func powerUnit(for symbol: String) -> UnitPower? {
        switch symbol {
        case "TW": return .terawatts
        case "GW": return .gigawatts
        case "MW": return .megawatts
        case "kW": return .kilowatts
        case "W": return .watts
        case "mW": return .milliwatts
        case "µW": return .microwatts
        case "nW": return .nanowatts
        case "pW": return .picowatts
        case "fW": return .femtowatts
        case "hp": return .horsepower
        default: return nil
        }
    }
    
    /// Converts a specific energy price (e.g., EUR/kWh) to a different energy unit.
    /// See https://developer.apple.com/documentation/foundation/unitenergy for more details on energy units.
    /// - Parameters:
    ///   - amount: The monetary value of the specific price to be converted.
    ///   - initialUnit: The initial energy unit.
    ///   - targetUnit: The target energy unit.
    /// - Returns: The converted price.
    func convertEnergyPrice(amount: Double, from initialUnit: UnitEnergy, to targetUnit: UnitEnergy) -> Double {
        let conversionFactor = 1 / Measurement<UnitEnergy>(value: 1, unit: initialUnit).converted(to: targetUnit).value
        return amount * conversionFactor
    }
    
    /// Converts a specific energy price (e.g., EUR/kWh) to a different energy unit.
    /// Only supports symbols listed in https://developer.apple.com/documentation/foundation/unitenergy
    /// - Parameters:
    ///   - amount: The monetary value of the specific price to be converted.
    ///   - initialUnitSymbol: The current symbol of the energy unit (e.g., kWh).
    ///   - targetUnitSymbol: The target symbol of the energy unit.
    /// - Returns: The converted price, nil if the symbol is not in the list of symbols.
    func convertEnergyPrice(amount: Double, from initialUnitSymbol: String, to targetUnitSymbol: String) -> Double? {
        if let initialUnit = energyUnit(for: initialUnitSymbol), let targetUnit = energyUnit(for: targetUnitSymbol) {
            return convertEnergyPrice(amount: amount, from: initialUnit, to: targetUnit)
        } else {
            return nil
        }
    }
}
