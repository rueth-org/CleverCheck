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
    var name: String
    var car: Car
    
    init(name: String, car: Car) {
        self.name = name
        self.car = car
    }
}
