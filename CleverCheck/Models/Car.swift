//
//  Car.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData

@Model
final class Car: Equatable {
    var id: UUID
    var make: String
    var model: String
    var defaultSOC: Double
    
    init(make: String, model: String, defaultSOC: Double = 0.8) {
        self.id = UUID()
        self.make = make
        self.model = model
        self.defaultSOC = defaultSOC
    }
    
    static func ==(lhs: Car, rhs: Car) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func new() -> Car {
        let car = Car(make: "Make", model: "Model")
        return car
    }
}
