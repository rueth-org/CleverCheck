//
//  ChargingLocation.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData

@Model
final class ChargingLocation {
    var id: UUID
    var name: String
    
    @Relationship(deleteRule: .nullify, inverse: \HomeConsumption.associatedChargingLocation)
    var associatedHomeConsumptions = [HomeConsumption]()
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingSession.charger)
    var chargers = [Charger]()
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
