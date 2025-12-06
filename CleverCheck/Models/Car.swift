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
    var id = UUID()
    var make: String
    var model: String
    var defaultSOC: Double
    
    @Relationship(deleteRule: .deny, inverse: \ChargingSession.car)
    var chargingSessions = [ChargingSession]()
    
    var description: String {
        return "\(make) \(model)"
    }
    
    init(make: String, model: String, defaultSOC: Double = 0.8) {
        self.make = make
        self.model = model
        self.defaultSOC = defaultSOC
    }
}
