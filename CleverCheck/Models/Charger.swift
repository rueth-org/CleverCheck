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
    @Attribute(.unique) var name: String
    var chargingLocation: ChargingLocation?
    
    init(name: String, chargingLocation: ChargingLocation? = nil) {
        self.name = name
        self.chargingLocation = chargingLocation
    }
}
