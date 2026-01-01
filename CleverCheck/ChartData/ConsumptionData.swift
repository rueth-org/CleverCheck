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
            case previousValue = "Previous value"
            case estimated = "Estimated"
        }
        
        private let distanceKilometers: Double
        private let consumedEnergyKWh: Double
        let since: Date
        let until: Date
        let quality: Quality
        
        var duration: TimeInterval {
            until.timeIntervalSince(since)
        }
        
        var durationFormatted: String {
            UserSettings.shared.format(duration / 86_400, withSignificantDigits: 3)
        }
        
        init(
            distance: Measurement<UnitLength>,
            energy: Measurement<UnitEnergy>,
            since: Date,
            until: Date,
            quality: Quality = .precise
        ) {
            self.distanceKilometers = distance.converted(to: .kilometers).value
            self.consumedEnergyKWh = energy.converted(to: .kilowattHours).value
            self.since = since
            self.until = until
            self.quality = quality
        }
        
        /// Calculates the consumption from the energy and distance.
        /// - Parameters:
        ///   - energyUnit: The desired unit of for the energy.
        ///   - distanceUnit: The desired unit for the distance.
        ///   - distanceMultiplier: If the consumption shall be calculated over, e.g., 100km, this value needs to be 100.
        ///   - energyOverDistance: If true, consumption is calculated as energy over distance, if false, as distance over energy.
        /// - Returns: A triple with (0) the calculcated consumption as double, (1) as string and (2) the unit (e.g., kWh/100km) as string
        func consumption(energyUnit: UnitEnergy, distanceUnit: UnitLength, distanceMultiplier: Int = 1, energyOverDistance: Bool = true) -> (Double, String, String) {
            let consumptionKWhPerKm = Measurement<UnitEnergy>(value: consumedEnergyKWh / distanceKilometers, unit: .kilowattHours)
            let consumptionEnergyUnitPerKm = consumptionKWhPerKm.converted(to: energyUnit)
            
            let conversionFactor = 1 / Measurement<UnitLength>(value: 1, unit: .kilometers).converted(to: distanceUnit).value
            let convertedEnergyPerDistance = consumptionEnergyUnitPerKm.value * conversionFactor * Double(distanceMultiplier)
            
            let value = energyOverDistance ? convertedEnergyPerDistance : 1.0 / convertedEnergyPerDistance
            
            // Compose the unit string
            let unitString = energyOverDistance ? "\(energyUnit.symbol)/\(distanceMultiplier != 1 ? String(distanceMultiplier) : "")\(distanceUnit.symbol)" : "\(distanceUnit.symbol)/\(energyUnit.symbol)"
            
            return (value, UserSettings.shared.format(value, withSignificantDigits: 3), unitString)
        }
    }
    
    let id: UUID = UUID()
    let sessions: [ChargingSession]
    let resolution: ChargingData.Resolution
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
                    let dateKey = ChargingData.dateKey(for: session.endTime, with: resolution)
                    result[dateKey] = Consumption(
                        distance: .init(value: distanceConsumed, unit: UserSettings.shared.distanceUnit),
                        energy: .init(value: consumedEnergy, unit: UserSettings.shared.energyUnit),
                        since: lastDate,
                        until: session.endTime
                    )
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
    
    init(modelContext: ModelContext, resolution: ChargingData.Resolution, relatedPlans: [ChargingCostPlan], sessions: [ChargingSession]) throws {
        if sessions.isEmpty {
            throw DataError(message: "No sessions available")
        }
        
        self.resolution = resolution
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
        
        for session in self.previousSessions ?? [] {
            debugPrint(session.endTime)
        }
    }
}
