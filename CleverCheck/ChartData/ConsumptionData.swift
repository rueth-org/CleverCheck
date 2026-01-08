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
        let distanceKilometers: Double
        let consumedEnergyKWh: Double
        let since: Date
        let until: Date
        
        var duration: TimeInterval {
            until.timeIntervalSince(since)
        }
        
        var durationFormatted: String {
            UserSettings.shared.format(duration / 86_400, withSignificantDigits: 3)
        }
        
        var consumptionDescription: String {
            let consumption = consumption()
            return "\(consumption.1) \(consumption.2)"
        }
        
        init(
            distance: Measurement<UnitLength>,
            energy: Measurement<UnitEnergy>,
            since: Date,
            until: Date
        ) {
            self.distanceKilometers = distance.converted(to: .kilometers).value
            self.consumedEnergyKWh = energy.converted(to: .kilowattHours).value
            self.since = since
            self.until = until
        }
        
        init(distanceKilometers: Double, consumedEnergyKWh: Double, since: Date, until: Date) {
            self.distanceKilometers = distanceKilometers
            self.consumedEnergyKWh = consumedEnergyKWh
            self.since = since
            self.until = until
        }
        
        /// Calculates the consumption from the energy and distance.
        /// - Parameters:
        ///   - energyUnit: The desired unit of for the energy.
        ///   - distanceUnit: The desired unit for the distance.
        ///   - distanceMultiplier: If the consumption shall be calculated over, e.g., 100km, this value needs to be 100.
        ///   - energyOverDistance: If true, consumption is calculated as energy over distance, if false, as distance over energy.
        /// - Returns: A triple with (0) the calculcated consumption as double, (1) as string and (2) the unit (e.g., kWh/100km) as string
        func consumption(
            energyUnit: UnitEnergy = UserSettings.shared.energyUnit,
            distanceUnit: UnitLength = UserSettings.shared.distanceUnit,
            distanceMultiplier: Int = UserSettings.shared.distanceMultiplier,
            energyOverDistance: Bool = UserSettings.shared.energyOverDistance
        ) -> (Double, String, String) {
            let consumptionKWhPerKm = Measurement<UnitEnergy>(value: consumedEnergyKWh / distanceKilometers, unit: .kilowattHours)
            let consumptionEnergyUnitPerKm = consumptionKWhPerKm.converted(to: energyUnit)
            
            let conversionFactor = 1 / Measurement<UnitLength>(value: 1, unit: .kilometers).converted(to: distanceUnit).value
            let convertedEnergyPerDistance = consumptionEnergyUnitPerKm.value * conversionFactor * Double(distanceMultiplier)
            
            let value = energyOverDistance ? convertedEnergyPerDistance : 1.0 / convertedEnergyPerDistance
            
            // Compose the unit string
            let unitString = energyOverDistance ? "\(energyUnit.symbol)/\(distanceMultiplier != 1 ? String(distanceMultiplier) : "")\(distanceUnit.symbol)" : "\(distanceUnit.symbol)/\(energyUnit.symbol)"
            
            return (value, UserSettings.shared.format(value, withSignificantDigits: 3), unitString)
        }
        
        static prefix func + (rhs: Consumption) -> Consumption {
            return rhs
        }
    }
    
    let id: UUID = UUID()
    let sessions: [ChargingSession]
    let timeBox: TimeBox
    let previousSessions: [ChargingSession]?
    
    var consumptions: [String: Consumption] {
        var previousMileage: Double? = nil
        var previousDate: Date? = nil
        var previousEnergy: Double = 0.0
        if var previousSessions = previousSessions {
            // Mileage and date are taken from first element of previousSessions, as this is the last reference mileage
            previousMileage = previousSessions.first?.mileage?.converted(to: UserSettings.shared.distanceUnit).value ?? 0.0
            previousDate = previousSessions.first?.endTime
            
            // Previous energy is the sum of charged energy of all previous sessions
            // except the first one, which is part of the previous circle
            previousSessions.removeFirst()
            previousEnergy = previousSessions.reduce(0.0) {
                $0 + ($1.chargedEnergy(in: UserSettings.shared.energyUnit).value)
            }
        }
        
        var result = [String: Consumption]()
        var lastMileage: Double? = previousMileage
        var lastDate: Date? = previousDate
        var consumedEnergy: Double = previousEnergy
        for session in sessions {
            if session.finalSOC != nil, session.finalSOC! == UserSettings.shared.referenceSOC, session.mileage != nil {
                // This is a session with reference SOC and mileage, so calculate average consumption
                let mileage = session.mileage!.converted(to: UserSettings.shared.distanceUnit).value
                consumedEnergy += session.chargedEnergy(in: UserSettings.shared.energyUnit).value
                
                if let lastMileage, let lastDate {
                    let distanceConsumed: Double = mileage - lastMileage
                    let dateKey = timeBox.getKeyForDate(session.endTime)
                    let consumption = Consumption(
                        distance: .init(value: distanceConsumed, unit: UserSettings.shared.distanceUnit),
                        energy: .init(value: consumedEnergy, unit: UserSettings.shared.energyUnit),
                        since: lastDate,
                        until: session.endTime
                    )
                    result[dateKey] = calculateAverageConsumption(consumption, result[dateKey])
                }
                
                // Set lastMileage and lastDate to current values
                lastMileage = mileage
                lastDate = session.endTime
                
                // Reset consumedEnergy
                consumedEnergy = 0.0
            } else {
                // We keep adding the energy
                consumedEnergy += session.chargedEnergy(in: UserSettings.shared.energyUnit).value
            }
        }
        return result
    }
    
    var totalConsumption: Consumption? {
        var result: Consumption? = nil
        for consumption in consumptions.values {
            result = calculateAverageConsumption(consumption, result)
        }
        return result
    }
    
    init(modelContext: ModelContext, timeBox: TimeBox, relatedPlans: [ChargingCostPlan], sessions: [ChargingSession]) throws {
        if sessions.isEmpty {
            throw DataError(message: "No sessions available")
        }
        
        self.timeBox = timeBox
        self.sessions = sessions
        
        // Identify the last session for the vehicle (via related plans) with a mileage and the reference SOC before the first session in scope
        let firstSessionEndTime = sessions.first!.endTime
        let previousReferenceSessionsWithFinalSOC = try modelContext.fetch(FetchDescriptor<ChargingSession>(
            predicate: #Predicate { session in
                session.mileageKilometer != nil && session.endTime < firstSessionEndTime && session.finalSOC != nil
            },
            sortBy: [SortDescriptor(\ChargingSession.endTime)]
        ))
        
        // Get the IDs of the related plans
        let relatedPlanIDs = Set(relatedPlans.map { $0.persistentModelID })
        
        // Filter by finalSOC = referenceSOC and related plans
        let previousReferenceSessions = previousReferenceSessionsWithFinalSOC.filter({
            $0.finalSOC == UserSettings.shared.referenceSOC && $0.chargingCostPlan != nil && relatedPlanIDs.contains($0.chargingCostPlan!.persistentModelID)
        })
        
        if previousReferenceSessions.isEmpty {
            self.previousSessions = nil
        } else {
            let previousReferenceSessionEndTime = previousReferenceSessions.last!.endTime
            
            // Get all sessions from the previous reference session to the last session before start of scope
            let previousSessions = try modelContext.fetch(FetchDescriptor<ChargingSession>(
                predicate: #Predicate { session in
                    session.endTime >= previousReferenceSessionEndTime && session.endTime < firstSessionEndTime
                },
                sortBy: [SortDescriptor(\ChargingSession.endTime)]
            ))
            self.previousSessions = previousSessions.filter({
                $0.chargingCostPlan != nil && relatedPlanIDs.contains($0.chargingCostPlan!.persistentModelID)
            })
        }
    }
    
    func calculateAverageConsumption(_ newConsumption: Consumption, _ existingConsumption: Consumption?) -> Consumption {
        if let existingConsumption {
            let newSince = existingConsumption.since
            let newUntil = newConsumption.until
            let newDistanceKilometers = existingConsumption.distanceKilometers + newConsumption.distanceKilometers
            let newEnergyConsumedkWh = existingConsumption.consumedEnergyKWh + newConsumption.consumedEnergyKWh
            
            return Consumption(
                distanceKilometers: newDistanceKilometers,
                consumedEnergyKWh: newEnergyConsumedkWh,
                since: newSince,
                until: newUntil
            )
        } else {
            return newConsumption
        }
    }
}
