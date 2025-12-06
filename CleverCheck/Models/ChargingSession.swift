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
    var id = UUID()
    var startTime: Date?
    var endTime: Date
    var charger: Charger
    var chargedEnergyKWh: Double
    var car: Car?
    var mileageKilometer: Double?
    var initialSOC: Double?
    var finalSOC: Double?
    
    @Transient var chargedEnergy: Measurement<UnitEnergy> {
        get {
            return Measurement<UnitEnergy>(value: chargedEnergyKWh, unit: .kilowattHours)
        }
        set {
            chargedEnergyKWh = newValue.converted(to: .kilowattHours).value
        }
    }
    
    @Transient var mileage: Measurement<UnitLength>? {
        get {
            if let mileageKilometer {
                return Measurement<UnitLength>(value: mileageKilometer, unit: .kilometers)
            } else {
                return nil
            }
        }
        set {
            mileageKilometer = newValue?.converted(to: .kilometers).value
        }
    }
    
    init(
        startTime: Date? = nil,
        endTime: Date,
        charger: Charger,
        chargedEnergy: Measurement<UnitEnergy>,
        car: Car,
        mileage: Measurement<UnitLength>? = nil,
        initialSOC: Double? = nil,
        finalSOC: Double? = nil,
        useDefaultFinalSOC: Bool = true
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.charger = charger
        self.chargedEnergyKWh = chargedEnergy.converted(to: .kilowattHours).value
        self.car = car
        self.mileageKilometer = mileage?.converted(to: .kilometers).value
        self.initialSOC = initialSOC
        if useDefaultFinalSOC {
            self.finalSOC = car.defaultSOC
        } else {
            self.finalSOC = finalSOC
        }
    }
}
