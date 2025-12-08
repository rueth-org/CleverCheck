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
    
    var id: UUID
    var homeConsumption: HomeConsumption?
    var label: String
    var amount: Cost
    var isGross: Bool
    var type: PriceElementType
    var vatRate: Double
    
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
        let precision = UserSettings.shared.precision(for: self.amount.amount)
        return "\(self.amount.amount.formatted(.number.precision(.fractionLength(precision)))) \(unitDescription)"
    }
    
    var netGrossDescription: String {
        isGross ? "Gross" : "Net"
    }
    
    init(id: UUID = UUID(), label: String, amount: Cost, isGross: Bool, type: PriceElementType, vatRate: Double? = nil) {
        self.id = id
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
