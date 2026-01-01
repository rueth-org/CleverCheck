//
//  PriceElement.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 02/12/2025.
//

import Foundation
import SwiftData

@Model
final class PriceElement: Identifiable, Equatable {
    enum PriceElementType: Codable, Hashable {
        static var descriptionDaily: String { NSLocalizedString("Daily", comment: "") }
        static var descriptionOnce: String { NSLocalizedString("Once", comment: "") }
        static var descriptionByConsumption: String { NSLocalizedString("By consumption", comment: "") }
        
        case daily
        case once
        case byConsumption(energyUnitSymbol: String)
        
        var unitExtension: String {
            switch self {
            case .daily:
                return NSLocalizedString("/day", comment: "")
            case .once:
                return ""
            case .byConsumption(let energyUnitSymbol):
                return "/\(energyUnitSymbol)"
            }
        }
        
        var description: String {
            switch self {
            case .daily: return PriceElementType.descriptionDaily
            case .once: return PriceElementType.descriptionOnce
            case .byConsumption: return PriceElementType.descriptionByConsumption
            }
        }
        
        static var allCases: [PriceElementType] {
            return [.daily, .once, .byConsumption(energyUnitSymbol: UserSettings.shared.energyUnit.symbol)]
        }
    }
    
    var id: UUID = UUID()
    var homeConsumption: HomeConsumption?
    var label: String = ""
    var amount: Cost = Cost(amount: 0.0)
    var isGross: Bool = true
    var type: PriceElementType = PriceElementType.byConsumption(energyUnitSymbol: "kWh")
    var vatRate: Double = 0.25
    
    var netAmount: Double {
        if isGross {
            return amount.amount / (1 + vatRate)
        } else {
            return amount.amount
        }
    }
    
    var grossAmount: Double {
        if isGross {
            return amount.amount
        } else {
            return amount.amount * (1 + vatRate)
        }
    }
    
    var unitDescription: String {
        "\(amount.currency)\(type.unitExtension)"
    }
    
    var amountDescription: String {
        return "\(UserSettings.shared.format(self.amount.amount, withSignificantDigits: 4)) \(unitDescription)"
    }
    
    var netGrossDescription: String {
        isGross ? "Gross" : "Net"
    }
    
    init(label: String, amount: Cost, isGross: Bool, type: PriceElementType, vatRate: Double? = nil) {
        self.label = label
        self.amount = amount
        self.type = type
        self.vatRate = vatRate ?? UserSettings.shared.vatRate
        self.isGross = isGross
    }
    
    func getAmount(isGross: Bool) -> Double {
        if isGross {
            return grossAmount
        } else {
            return netAmount
        }
    }
    
    static func == (lhs: PriceElement, rhs: PriceElement) -> Bool {
        lhs.id == rhs.id
    }
}
