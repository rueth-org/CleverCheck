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
    var type: PriceElementType = PriceElementType.byConsumption(energyUnitSymbol: UserSettings.shared.energyUnitSymbol)
    var vatRate: Double = 0.25
    
    /// Returns the amount converted to the user's selected currency. If conversion fails, returns the original amount.
    var converted: Cost {
        amount.converted(to: UserSettings.shared.currencyIdentifier) ?? amount
    }
    
    /// Returns the net amount based on the converted gross amount and VAT rate. If the original amount is already net, it simply returns the converted amount.
    var exclVAT: Cost {
        if isGross {
            return Cost(amount: converted.amount / (1 + vatRate), currency: converted.currency)
        } else {
            return converted
        }
    }
    
    /// Returns the gross amount based on the converted net amount and VAT rate. If the original amount is already gross, it simply returns the converted amount.
    var inclVAT: Cost {
        if isGross {
            return converted
        } else {
            return Cost(amount: converted.amount * (1 + vatRate), currency: converted.currency)
        }
    }
    
    var unitDescription: String {
        "\(converted.currency)\(type.unitExtension)"
    }
    
    var amountDescription: String {
        return "\(UserSettings.shared.format(self.converted.amount, withSignificantDigits: 4)) \(unitDescription)"
    }
    
    var netGrossDescription: String {
        isGross ? "Gross" : "Net"
    }
    
    init(label: String, amount: Cost, inclVAT: Bool, type: PriceElementType, vatRate: Double? = nil) {
        self.label = label
        self.amount = amount
        self.type = type
        self.vatRate = vatRate ?? UserSettings.shared.vatRate
        self.isGross = inclVAT
    }
    
    /// Returns the converted cost in the user's selected currency, either gross or net based on the isGross parameter.
    /// - Parameter isGross: If true, returns the gross amount; if false, returns the net amount.
    /// - Returns: The converted cost. If conversion fails, returns the original cost.
    func getConvertedCost(includingVAT: Bool) -> Cost {
        if includingVAT {
            return inclVAT
        } else {
            return exclVAT
        }
    }
    
    static func == (lhs: PriceElement, rhs: PriceElement) -> Bool {
        lhs.id == rhs.id
    }
}
