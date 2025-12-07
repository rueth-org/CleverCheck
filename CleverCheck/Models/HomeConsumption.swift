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
}
