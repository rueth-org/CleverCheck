//
//  CleverCheckTests.swift
//  CleverCheckTests
//
//  Created by Ulrich Rüth on 30/12/2025.
//

import Testing
import Foundation
@testable import CleverCheck

struct UserSettingsTest {

    @Test func example() async throws {
        // Keep an example test to satisfy templates.
        #expect(Bool(true))
    }
    
    @Test(arguments: [
        (123.45678, "123", "123", "123", "123"),
        (12.345678, "12", "12", "12", "12.3"),
        (1.2345678, "1", "1", "1.2", "1.23"),
        (0.12345678, "0.1", "0.1", "0.12", "0.123")
    ])
    func formatWithSignificantUnits(
        _ value: Double,
        _ expected0: String,
        _ expected1: String,
        _ expected2: String,
        _ expected3: String
    ) async throws {
        let settings = UserSettings.shared
        #expect(settings.format(value, withSignificantDigits: 0).replacing(",", with: ".") == expected0)
        #expect(settings.format(value, withSignificantDigits: 1).replacing(",", with: ".") == expected1)
        #expect(settings.format(value, withSignificantDigits: 2).replacing(",", with: ".") == expected2)
        #expect(settings.format(value, withSignificantDigits: 3).replacing(",", with: ".") == expected3)
    }

    @Test func convertEnergyPrice_withUnits() async throws {
        let settings = UserSettings.shared

        // Convert 1.0 EUR/kWh to EUR/J -> expected = 1 / (1 kWh in J)
        let result = settings.convertEnergyPrice(amount: 1.0, from: UnitEnergy.kilowattHours, to: UnitEnergy.joules)
        let expected = 1.0 / Measurement<UnitEnergy>(value: 1.0, unit: UnitEnergy.kilowattHours).converted(to: UnitEnergy.joules).value

        // Use a small tolerance for floating point comparison
        #expect(abs(result - expected) < 1e-12)
    }

    @Test func convertEnergyPrice_withSymbols() async throws {
        let settings = UserSettings.shared

        // Convert 2.5 EUR/kWh to EUR/J using symbols
        guard let result = settings.convertEnergyPrice(amount: 2.5, from: "kWh", to: "J") else {
            #expect(Bool(false))
            return
        }

        let expected = 2.5 * (1.0 / Measurement<UnitEnergy>(value: 1.0, unit: UnitEnergy.kilowattHours).converted(to: UnitEnergy.joules).value)
        #expect(abs(result - expected) < 1e-12)
    }

    @Test func convertEnergyPrice_withUnknownSymbol_returnsNil() async throws {
        let settings = UserSettings.shared

        let result = settings.convertEnergyPrice(amount: 1.0, from: "kWh", to: "unknown")
        #expect(result == nil)
    }

}
