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
    @Attribute(.unique) var name: String
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingSession.chargingLocation)
    var chargingSessions = [ChargingSession]()
    
    init(name: String) {
        self.name = name
    }
}
