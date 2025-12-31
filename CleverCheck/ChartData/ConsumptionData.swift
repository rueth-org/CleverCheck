//
//  ConsumptionData.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 31/12/2025.
//

import Foundation
import SwiftData

struct ConsumptionData: Identifiable {
    struct Consumption {
        enum Quality: String {
            case precise = "Precise"
            case estimated = "Estimated"
        }
        
        private let distanceKilometers: Double
        private let consumedEnergyKWh: Double
        let quality: Quality
        
        init(distance: Measurement<UnitLength>, energy: Measurement<UnitEnergy>, quality: Quality = .precise) {
            self.distanceKilometers = distance.converted(to: .kilometers).value
            self.consumedEnergyKWh = energy.converted(to: .kilowattHours).value
            self.quality = quality
        }
        
        /// Calculates the consumption from the energy and distance.
        /// - Parameters:
        ///   - energyUnit: The desired unit of for the energy.
        ///   - distanceUnit: The desired unit for the distance.
        ///   - distanceMultiplier: If the consumption shall be calculated over, e.g., 100km, this value needs to be 100.
        ///   - energyOverDistance: If true, consumption is calculated as energy over distance, if false, as distance over energy.
        /// - Returns: A touple with the calculcated consumption as double and the unit (e.g., kWh/100km) as string
        func consumption(energyUnit: UnitEnergy, distanceUnit: UnitLength, distanceMultiplier: Int = 1, energyOverDistance: Bool = true) -> (Double, String) {
            let consumptionKWhPerKm = Measurement<UnitEnergy>(value: consumedEnergyKWh / distanceKilometers, unit: .kilowattHours)
            let consumptionEnergyUnitPerKm = consumptionKWhPerKm.converted(to: energyUnit)
            
            let conversionFactor = 1 / Measurement<UnitLength>(value: 1, unit: .kilometers).converted(to: distanceUnit).value
            var convertedEnergyPerDistance = consumptionEnergyUnitPerKm.value * conversionFactor * Double(distanceMultiplier)
            
            let value = energyOverDistance ? convertedEnergyPerDistance : 1.0 / convertedEnergyPerDistance
            
            // Compose the unit string
            let unitString = energyOverDistance ? "\(energyUnit.symbol)/\(distanceMultiplier != 1 ? String(distanceMultiplier) : "")\(distanceUnit.symbol)" : "\(distanceUnit.symbol)/\(energyUnit.symbol)"
            
            return (value, unitString)
        }
    }
    
    let id: UUID = UUID()
    let sessions: [ChargingSession]
    let previousSessions: [ChargingSession]?
    
    var consumptions: [ChargingSession: Consumption] {
        var previousMileage: Double? = nil
        var previousEnergy: Double = 0.0
        if let previousSessions = previousSessions {
            // Mileage is taken from first element of previousSessions, as this is the last reference mileage
            previousMileage = previousSessions.first?.mileage?.converted(to: UserSettings.shared.distanceUnit).value ?? 0.0
            
            // Previous energy is the sum of charged energy of all previous sessions
            previousEnergy = previousSessions.reduce(0.0) {
                $0 + ($1.chargedEnergy(in: UserSettings.shared.energyUnit).value)
            }
        }
        
        var result = [ChargingSession: Consumption]()
        var lastMileage: Double? = previousMileage
        var consumedEnergy: Double = previousEnergy
        for session in sessions {
            if session.finalSOC != nil, session.finalSOC! == UserSettings.shared.referenceSOC, session.mileage != nil {
                // This is a session with reference SOC and mileage, so calculate average consumption
                let mileage = session.mileage!.converted(to: UserSettings.shared.distanceUnit).value
                consumedEnergy += session.chargedEnergy(in: UserSettings.shared.energyUnit).value
                
                if let lastMileage {
                    let distanceConsumed: Double = mileage - lastMileage
                    result[session] = Consumption(
                        distance: .init(value: distanceConsumed, unit: UserSettings.shared.distanceUnit),
                        energy: .init(value: consumedEnergy, unit: UserSettings.shared.energyUnit)
                    )
                }
                
                // Reset lastMileage and consumedEnergy
            } else {
                // We keep adding the energy
                consumedEnergy += session.chargedEnergy(in: UserSettings.shared.energyUnit).value
            }
        }
        return result
    }
    
    init(modelContext: ModelContext, sessions: [ChargingSession]) throws {
        if sessions.isEmpty {
            throw DataError(message: "No sessions available")
        }
        
        self.sessions = sessions
        
        // Identify the last session with a mileage and the reference SOC before the first session in scope
        let firstSessionEndTime = sessions.first!.endTime
        let previousReferenceSessionsWithFinalSOC = try modelContext.fetch(FetchDescriptor<ChargingSession>(
            predicate: #Predicate { session in
                session.mileage != nil && session.endTime < firstSessionEndTime && session.finalSOC != nil
            }
        ))
        let previousReferenceSessions = previousReferenceSessionsWithFinalSOC.filter({
            $0.finalSOC == UserSettings.shared.referenceSOC
        })
        
        if previousReferenceSessions.isEmpty {
            self.previousSessions = nil
        } else {
            let previousReferenceSessionEndTime = previousReferenceSessions.last!.endTime
            
            // Get all sessions from the previous reference session to the last session before start of scope
            self.previousSessions = try modelContext.fetch(FetchDescriptor<ChargingSession>(
                predicate: #Predicate { session in
                    session.endTime >= previousReferenceSessionEndTime && session.endTime < firstSessionEndTime
                }
            ))
        }
    }
}
