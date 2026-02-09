//
//  UserSettings.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 23/11/2025.
//

import Foundation
import SwiftUI
import SwiftData

final class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    enum EnergyUnit: String, CaseIterable, Identifiable {
        case kWh
        case cal
        case J
        case kJ
        case kCal
        
        var id: String { rawValue }
        
        var unit: UnitEnergy {
            switch self {
            case .kWh: return .kilowattHours
            case .cal: return .calories
            case .J: return .joules
            case .kJ: return .kilojoules
            case .kCal: return .kilocalories
            }
        }
        
        var symbol: String { rawValue }
    }
    
    enum PowerUnit: String, CaseIterable, Identifiable {
        case TW
        case GW
        case MW
        case kW
        case W
        case mW
        case µW
        case nW
        case pW
        case fW
        case hp
        
        var id: String { rawValue }
        
        var unit: UnitPower {
            switch self {
            case .TW: return .terawatts
            case .GW: return .gigawatts
            case .MW: return .megawatts
            case .kW: return .kilowatts
            case .W: return .watts
            case .mW: return .milliwatts
            case .µW: return .microwatts
            case .nW: return .nanowatts
            case .pW: return .picowatts
            case .fW: return .femtowatts
            case .hp: return .horsepower
            }
        }
        
        var symbol: String { rawValue }
    }
    
    @AppStorage("measurementSystem") var measurementSystemIdentifier: String = Locale.current.measurementSystem.identifier
    @AppStorage("currencyIdentifier") var currencyIdentifier: String = Locale.current.currency?.identifier ?? "EUR"
    @AppStorage("energyUnitSymbol") var energyUnitSymbol: String = "kWh"
    @AppStorage("powerUnitSymbol") var powerUnitSymbol: String = "kW"
    @AppStorage("energyOverDistance") var energyOverDistance: Bool = true
    @AppStorage("distanceMultiplier") var distanceMultiplier: Int = 100
    @AppStorage("vatRate") var vatRate: Double = 0.25
    @AppStorage("displayGrossPrices") var displayGrossPrices: Bool = true
    
    @AppStorage("selectedCarId") private var selectedCarIdRaw: String = ""
    var selectedCarId: String? {
        get { selectedCarIdRaw.isEmpty ? nil : selectedCarIdRaw }
        set { selectedCarIdRaw = newValue ?? "" }
    }
    
    @AppStorage("selectedLocationId") private var selectedLocationIdRaw: String = ""
    var selectedLocationId: String? {
        get { selectedLocationIdRaw.isEmpty ? nil : selectedLocationIdRaw }
        set { selectedLocationIdRaw = newValue ?? "" }
    }
    
    @AppStorage("preferredCurrencies") private var preferredCurrenciesRaw: String = "DKK,PLN,RON,SEK,CZK,HUF,GBP,CHF,NOK,BAM,RSD,ALL"
    @Published var preferredCurrencies: [String] = [] {
        didSet {
            // Sync to AppStorage string when changed
            preferredCurrenciesRaw = preferredCurrencies.joined(separator: ",")
        }
    }
    
    @AppStorage("referenceSOC") var referenceSOC: Double = 0.8
    
    /// Stores the instance of CurrencyConverterService after async initialization
    var currencyConverterService: CurrencyConverterService?
    
    // MARK: - Async Initializers
    /// Call this method to asynchronously and safely initialize the currencyConverterService property
    @MainActor
    func loadCurrencyConverterService() async throws {
        self.currencyConverterService = try await CurrencyConverterService.makeService()
    }
    
    // TODO make Show Archived Cars/Plans... persistent
    
    var consumptionUnitSymbol: String {
        if energyOverDistance {
            "\(energyUnit.symbol)/\(distanceMultiplier != 1 ? String(distanceMultiplier) : "")\(distanceUnit.symbol)"
        } else {
            "\(distanceMultiplier != 1 ? String(distanceMultiplier) : "")\(distanceUnit.symbol)/\(energyUnit.symbol)"
        }
    }
    
    var distanceUnit: UnitLength {
        switch measurementSystemIdentifier {
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
        // Initialize published property from stored string
        preferredCurrencies = preferredCurrenciesRaw.split(separator: ",").map { String($0) }
    }
    
    func format(_ value: Double, withSignificantDigits: Int) -> String {
        if value == .infinity || value == .greatestFiniteMagnitude { return "-" }
        let integerPart = Int(floor(value)) // Get the whole number part
        let digitCount = String(integerPart.magnitude).count // Count digits in the magnitude
        let digits = withSignificantDigits < digitCount ? digitCount : withSignificantDigits
        let style = Decimal.FormatStyle(locale: Locale.current)
            .rounded(rule: .toNearestOrAwayFromZero)
            .precision(.significantDigits(1...digits))
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
