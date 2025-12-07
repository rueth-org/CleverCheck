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
    enum PriceElementType: String, Codable, CaseIterable {
        case daily, once, byConsumption = "by consumption"
        
        func unitExtension(energyUnit: String) -> String {
            switch self {
            case .daily:
                return NSLocalizedString("/day", comment: "")
            case .once:
                return ""
            case .byConsumption:
                return "/\(energyUnit)"
            }
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
    
    init(id: UUID = UUID(), label: String, amount: Cost, isGross: Bool, type: PriceElementType, vatRate: Double? = nil) {
        self.id = id
        self.label = label
        self.amount = amount
        self.type = type
        self.vatRate = vatRate ?? UserSettings.shared.vatRate
        self.isGross = isGross
    }
    
    func description(homeConsumption: HomeConsumption?) -> String {
        let amountToBeDisplayed = self.getAmount(isGross: UserSettings.shared.displayGrossPrices)
        let precision = amountToBeDisplayed < 1 ? 4 : 2
        return "\(amountToBeDisplayed.formatted(.number.precision(.fractionLength(precision)))) \(unitDescription(homeConsumption: homeConsumption))"
    }
    
    func unitDescription(homeConsumption: HomeConsumption?) -> String {
        "\(amount.currency)\(type.unitExtension(energyUnit: homeConsumption?.consumption.unit.symbol ?? UserSettings.shared.energyUnit.symbol))"
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
