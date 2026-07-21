//
//  FuelConsumption.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 21/07/2026.
//

import Foundation

struct FuelConsumption: Codable, Hashable, Comparable {
    var amount: Double
    var unit: UserSettings.FuelConsumptionUnit = UserSettings.shared.fuelConsumptionUnit
    
    func converted(to targetUnit: UserSettings.FuelConsumptionUnit) -> FuelConsumption {
        var convertedAmount: Double
        switch (unit, targetUnit) {
        case (.litersPer100km, .milesPerGallonUS):
            convertedAmount = 235.214583 / amount
        case (.litersPer100km, .milesPerGallonImperial):
            convertedAmount = 282.480936 / amount
        case (.litersPer100km, .kilometersPerLiter):
            convertedAmount = 100 / amount
        case (.milesPerGallonUS, .litersPer100km):
            convertedAmount = 235.214583 / amount
        case (.milesPerGallonUS, .milesPerGallonImperial):
            convertedAmount = amount * 1.20095
        case (.milesPerGallonUS, .kilometersPerLiter):
            convertedAmount = amount * 0.425144
        case (.milesPerGallonImperial, .litersPer100km):
            convertedAmount = 282.480936 / amount
        case (.milesPerGallonImperial, .milesPerGallonUS):
            convertedAmount = amount * 0.832674
        case (.milesPerGallonImperial, .kilometersPerLiter):
            convertedAmount = amount * 0.354006
        case (.kilometersPerLiter, .litersPer100km):
            convertedAmount = 100 / amount
        case (.kilometersPerLiter, .milesPerGallonUS):
            convertedAmount = amount * 2.35215
        case (.kilometersPerLiter, .milesPerGallonImperial):
            convertedAmount = amount * 2.82481
        default:
            convertedAmount = amount // Same unit conversion returns the same value
        }
        
        return FuelConsumption(amount: convertedAmount, unit: targetUnit)
    }
    
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSNumber(value: self.converted(to: UserSettings.shared.fuelConsumptionUnit).amount)) ?? "–") \(unit.symbol)"
    }
    
    static func < (lhs: FuelConsumption, rhs: FuelConsumption) -> Bool {
        let lhsConverted = lhs.converted(to: .litersPer100km).amount
        let rhsConverted = rhs.converted(to: .litersPer100km).amount
        return lhsConverted < rhsConverted
    }
}
