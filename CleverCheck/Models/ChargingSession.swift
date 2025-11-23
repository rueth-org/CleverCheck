//
//  ChargingSession.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData

@Model
final class ChargingSession {
    var startTime: Date?
    var endTime: Date
    var chargingLocation: ChargingLocation?
    var amount: Double
    var car: Car
    var mileage: Int?
    var initialSOC: Double?
    var finalSOC: Double?
    
    init(
        startTime: Date? = nil,
        endTime: Date,
        chargingLocation: ChargingLocation? = nil,
        amount: Double,
        car: Car,
        mileage: Int? = nil,
        initialSOC: Double? = nil,
        finalSOC: Double? = nil,
        useDefaultFinalSOC: Bool = true
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.chargingLocation = chargingLocation
        self.amount = amount
        self.car = car
        self.mileage = mileage
        self.initialSOC = initialSOC
        if useDefaultFinalSOC {
            self.finalSOC = car.defaultSOC
        } else {
            self.finalSOC = finalSOC
        }
    }
    
    static func new() -> ChargingSession {
        let session = ChargingSession(
            endTime: Date.now,
            amount: 0.0,
            car: Car.new()
        )
        
        return session
    }
}
