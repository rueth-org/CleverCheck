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
    static let settings = UserSettings()
    
    var measurementSystem: Locale.MeasurementSystem = Locale.current.measurementSystem
    var currency: Locale.Currency = Locale.current.currency ?? .init("EUR")
    
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
    
    var currencyCode: String {
        currency.identifier
    }
    
    private init() {
        // Empty on purpose
    }
}
