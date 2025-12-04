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
    
    var id = UUID()
    var homeConsumption: HomeConsumption?
    var label: String
    var amount: Cost
    var type: PriceElementType
    var vatRate: Double
    
    init(id: UUID = UUID(), label: String, amount: Cost, type: PriceElementType, vatRate: Double? = nil) {
        self.label = label
        self.amount = amount
        self.type = type
        self.vatRate = vatRate ?? UserSettings.shared.vatRate
    }
    
    func description(homeConsumption: HomeConsumption?) -> String {
        "\(amount.amount.formatted()) \(unitDescription(homeConsumption: homeConsumption))"
    }
    
    func unitDescription(homeConsumption: HomeConsumption?) -> String {
        "\(amount.currency.identifier)\(type.unitExtension(energyUnit: homeConsumption?.consumption.unit.symbol ?? UserSettings.shared.energyUnit.symbol))"
    }
    
    static func == (lhs: PriceElement, rhs: PriceElement) -> Bool {
        lhs.id == rhs.id
    }
}
