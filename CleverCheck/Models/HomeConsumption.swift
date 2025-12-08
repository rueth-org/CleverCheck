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
    var id: UUID
    var name: String
    var validFrom: Date
    var validUntil: Date
    var consumptionKWh: Double
    var associatedChargingLocation: ChargingLocation?
    
    @Relationship(deleteRule: .cascade, inverse: \PriceElement.homeConsumption)
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
    
    var numberOfDays: Int {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: validFrom)
        let endDate = calendar.startOfDay(for: validUntil)
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        validFrom: Date,
        validUntil: Date,
        consumption: Measurement<UnitEnergy>,
        associatedChargingLocation: ChargingLocation? = nil
    ) {
        self.id = id
        self.name = name
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.consumptionKWh = consumption.converted(to: .kilowattHours).value
        self.associatedChargingLocation = associatedChargingLocation
    }
    
    func totalPrice(isGross: Bool = true) -> Double {
        return priceElements.reduce(0.0) {
            switch $1.type {
            case .daily:
                return $0 + ($1.grossAmount * Double(numberOfDays))
            case .once:
                return $0 + $1.grossAmount
            case .byConsumption(let energyUnitSymbol):
                guard let energyUnit = UserSettings.shared.energyUnit(for: energyUnitSymbol) else {
                    fatalError("Unknown energy unit symbol: \(energyUnitSymbol)")
                }
                let convertedConsumption = consumption.converted(to: energyUnit).value
                return $0 + ($1.grossAmount * convertedConsumption)
            }
        }
    }
}
