//
//  Car.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData

@Model
final class Car {
    var id: UUID
    var make: String
    var model: String
    var defaultSOC: Double
    var isArchived: Bool = false
    
    @Relationship(deleteRule: .deny, inverse: \ChargingSession.car)
    var chargingSessions = [ChargingSession]()
    
    var description: String {
        return "\(make) \(model)"
    }
    
    init(id: UUID = UUID(), make: String, model: String, defaultSOC: Double = 0.8) {
        self.id = id
        self.make = make
        self.model = model
        self.defaultSOC = defaultSOC
    }
}
