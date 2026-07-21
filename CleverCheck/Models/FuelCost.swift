//
//  FuelConsumption.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 21/07/2026.
//

import Foundation

struct FuelCost: Hashable, Comparable {
    var amount: Cost
    var unit: UserSettings.FuelCostUnit = UserSettings.shared.fuelConsumptionUnit.fuelCostUnit
    
    func converted(to targetUnit: UserSettings.FuelCostUnit) -> FuelCost {
        var convertedAmount: Double
        switch (unit, targetUnit) {
        case (.costPerLiter, .costPerLiter):
            convertedAmount = amount.amount
        case (.costPerLiter, .costPerGallonUS):
            convertedAmount = amount.amount * 3.78541
        case (.costPerLiter, .costPerGallonImperial):
            convertedAmount = amount.amount * 4.54609
        case (.costPerGallonUS, .costPerLiter):
            convertedAmount = amount.amount / 3.78541
        case (.costPerGallonUS, .costPerGallonUS):
            convertedAmount = amount.amount
        case (.costPerGallonUS, .costPerGallonImperial):
            convertedAmount = amount.amount * 1.20095
        case (.costPerGallonImperial, .costPerLiter):
            convertedAmount = amount.amount / 4.54609
        case (.costPerGallonImperial, .costPerGallonUS):
            convertedAmount = amount.amount / 1.20095
        case (.costPerGallonImperial, .costPerGallonImperial):
            convertedAmount = amount.amount
        }
        return FuelCost(amount: Cost(amount: convertedAmount, currency: amount.currency), unit: targetUnit)
    }
    
    func formatted() -> String {
        "\(amount.formatted())\(unit.unitExtension)"
    }
    
    static func < (lhs: FuelCost, rhs: FuelCost) -> Bool {
        return lhs.amount < rhs.amount
    }
}
