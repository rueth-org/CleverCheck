//
//  Location.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData

@Model
final class Charger {
    var id: UUID = UUID()
    var name: String = ""
    var location: Location?
    var maxPowerKW: Double?
    var isArchived: Bool = false
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingCostPlan.charger)
    var chargingCostPlans: [ChargingCostPlan]?
    
    @Transient var maxPower: Measurement<UnitPower>? {
        get {
            return maxPowerKW == nil ? nil : Measurement<UnitPower>(value: maxPowerKW!, unit: .kilowatts)
        }
        set {
            maxPowerKW = newValue == nil ? nil : newValue!.converted(to: .kilowatts).value
        }
    }
    
    var description: String {
        var description = name
        if let location = location {
            description += " - \(location.name)"
        }
        return description
    }
    
    init(name: String, location: Location? = nil, maxPower: Measurement<UnitPower>? = nil) {
        self.name = name
        self.location = location
        self.maxPower = maxPower
    }
}
