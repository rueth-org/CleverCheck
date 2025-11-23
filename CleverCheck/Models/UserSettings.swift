//
//  UserSettings.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 23/11/2025.
//

import Foundation
import SwiftData

@Model
final class UserSettings {
    enum UnitDistance: String, Codable, CaseIterable {
        static let conversionFactor = 1.609
        
        case kilometer = "km"
        case mile = "mi"
        
        func toKilometers(miles: Double) -> Double {
            return miles * Self.conversionFactor
        }
        
        func toMiles(kilometers: Double) -> Double {
            return kilometers / Self.conversionFactor
        }
        
        func convert(distance: Double) -> Double {
            if self == .kilometer {
                return toMiles(kilometers: distance)
            } else {
                return toKilometers(miles: distance)
            }
        }
    }
    
    static let userSettings = UserSettings(unitDistance: .kilometer)
    
    var unitDistance: UnitDistance
    
    private init(unitDistance: UnitDistance) {
        self.unitDistance = unitDistance
    }
}
