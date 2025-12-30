//
//  SampleMasterData.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 29/12/2025.
//

import Foundation
import SwiftData

struct SampleMasterData {
    static func cars() -> [Car] {
        let cars = [
            Car(make: "Audi", model: "A3 e-tron Avant", defaultSOC: 0.8),   // 0: Audi
            Car(make: "VW", model: "ID.3", defaultSOC: 0.8)                 // 1: VW
        ]
        
        return cars
    }
    
    static func locations() -> [Location] {
        let locations = [
            Location(name: "Irisvej 33"),       // 0: Irisvej 33
            Location(name: "Clever netværk")    // 1: Clever netværk
        ]
        
        return locations
    }
    
    static func chargers() -> [Charger] {
        let locations = locations()
        
        let chargers = [
            Charger(name: "Verdo", location: locations[0], maxPower: .init(value: 11, unit: .kilowatts)),   // 0: Verdo - Irisvej 33
            Charger(name: "Clever", location: locations[0], maxPower: .init(value: 11, unit: .kilowatts)),  // 1: Clever - Irisvej 33
            Charger(name: "Clever", location: locations[1]),                                                // 2: Clever - Clever netværk
            Charger(name: "Andre lader")                                                                    // 3: Andre lader
        ]
        
        return chargers
    }
    
    static func chargingCostPlans() -> [ChargingCostPlan] {
        let cars = cars()
        let chargers = chargers()
        let locations = locations()
        
        var plans: [ChargingCostPlan] = [
            // 0: Audi - Clever netværk - flatrate
            ChargingCostPlan(car: cars[0], charger: chargers[2], planType: .flatrate, monthlyRate: Cost(amount: 899, currency: "DKK")),
            // 1: Audi - Andre lader - individual
            ChargingCostPlan(car: cars[0], charger: chargers[3], planType: .individual),
            // 2: VW - Verdo Irisvej 33 - home consumption
            ChargingCostPlan(car: cars[1], charger: chargers[0], planType: .homeConsumption, relatedLocation: locations[0]),
            // 3: VW - Clever netværk - individual
            ChargingCostPlan(car: cars[1], charger: chargers[2], planType: .individual, defaultEnergyPrice: Cost(amount: 4.99, currency: "DKK")),
            // 4: VW - Andre lader - individual
            ChargingCostPlan(car: cars[1], charger: chargers[3], planType: .individual)
        ]
        
        // 5: Audi - Clever Irisvej 33 - refunded via 0
        plans.append(ChargingCostPlan(car: cars[0], charger: chargers[1], planType: .refunded, relatedLocation: locations[0], includedInOtherPlan: plans[0]))
        
        return plans
    }
    
    static func masterSampleData(in modelContext: ModelContext) {
        let plans = chargingCostPlans()
        for plan in plans {
            modelContext.insert(plan)
        }
        try? modelContext.save()
    }
}
