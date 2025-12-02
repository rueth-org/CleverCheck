//
//  HomeConsumption.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 30/11/2025.
//

import Foundation
import SwiftData

@Model
final class HomeConsumption {
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
    
    struct PriceElement: Identifiable, Equatable, Codable {
        var id = UUID()
        var label: String
        var amount: Cost
        var type: PriceElementType
        var vatRate: Double = UserSettings.settings.vat
        
        func description(homeConsumption: HomeConsumption?) -> String {
            "\(amount.amount.formatted()) \(unitDescription(homeConsumption: homeConsumption))"
        }
        
        func unitDescription(homeConsumption: HomeConsumption?) -> String {
            "\(amount.currency.identifier)\(type.unitExtension(energyUnit: homeConsumption?.consumption.unit.symbol ?? UserSettings.settings.energyUnit.symbol))"
        }
        
        static func == (lhs: HomeConsumption.PriceElement, rhs: HomeConsumption.PriceElement) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    var id = UUID()
    var name: String
    var validFrom: Date
    var validUntil: Date
    var consumptionKWh: Double
    var associatedChargingLocation: ChargingLocation?
    var priceElements: [PriceElement] = []
    
    @Transient var consumption: Measurement<UnitEnergy> {
        get {
            return Measurement<UnitEnergy>(value: consumptionKWh, unit: .kilowattHours)
        }
        set {
            consumptionKWh = newValue.converted(to: .kilowattHours).value
        }
    }
    
    var description: String {
        if associatedChargingLocation != nil {
            return "\(name) (\(associatedChargingLocation!.name))"
        } else {
            return "\(name)"
        }
    }
    
    init(name: String, validFrom: Date, validUntil: Date, consumption: Measurement<UnitEnergy>) {
        self.name = name
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.consumptionKWh = consumption.converted(to: .kilowattHours).value
    }
}
