//
//  ChargingLocation.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData

@Model
final class Charger {
    var id: UUID
    var name: String
    var chargingLocation: ChargingLocation?
    
    var description: String {
        var description = name
        if let location = chargingLocation {
            description += " (\(location.name))"
        }
        return description
    }
    
    init(id: UUID = UUID(), name: String, chargingLocation: ChargingLocation? = nil) {
        self.id = id
        self.name = name
        self.chargingLocation = chargingLocation
    }
}
