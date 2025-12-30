//
//  CleverCheckTests.swift
//  CleverCheckTests
//
//  Created by Ulrich Rüth on 30/12/2025.
//

import Testing
import Foundation
@testable import CleverCheck

struct CleverCheckTests {

    @Test func example() async throws {
        // Keep an example test to satisfy templates.
        #expect(Bool(true))
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
