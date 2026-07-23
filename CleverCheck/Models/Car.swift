//
//  Car.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Car {
    struct EnergyData: Identifiable, GraphItem {
        let id = UUID()
        let legendLabel: String
        let chargedEnergy: Measurement<UnitEnergy>
        let displayColor: DisplayColor
        
        static func < (lhs: Car.EnergyData, rhs: Car.EnergyData) -> Bool {
            lhs.legendLabel < rhs.legendLabel
        }
    }
    
    struct CostData: Identifiable, GraphItem {
        let id = UUID()
        let legendLabel: String
        let cost: Cost
        let displayColor: DisplayColor
        
        static func < (lhs: Car.CostData, rhs: Car.CostData) -> Bool {
            lhs.legendLabel < rhs.legendLabel
        }
    }
    
    var id: UUID = UUID()
    var make: String = ""
    var model: String = ""
    var defaultSOC: Double = 0.8
    var netBatteryCapacityKWh: Double?
    var maxChargingPowerkW: Double?
    var isArchived: Bool = false
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingCostPlan.car)
    var chargingCostPlans: [ChargingCostPlan]?
    
    var description: String {
        return "\(make) \(model)"
    }
    
    init(make: String, model: String, defaultSOC: Double = 0.8) {
        self.make = make
        self.model = model
        self.defaultSOC = defaultSOC
    }
    
    /// Aggregates values from all charging cost plans using the provided selector.
    /// - Parameters:
    ///   - selector: A closure that extracts an array of values from each plan.
    /// - Returns: A flattened array of aggregated values.
    @MainActor
    private func aggregateFromPlans<T>(_ selector: (ChargingCostPlan) -> [T]) -> [T] {
        guard let chargingCostPlans else { return [] }
        return chargingCostPlans.flatMap(selector)
    }
    
    /// Returns all charging session in the given time box, sorted chronologically by end time.
    /// - Parameter timeBox: The time box to limit the charging sessions to. If nil, all available charging sessions are returned.
    /// - Returns: The charging sessions.
    @MainActor
    func chargingSessions(in timeBox: TimeBox?) -> [ChargingSession] {
        let allSessions = aggregateFromPlans { $0.chargingSessions ?? [] }
        guard let timeBox else { return allSessions.sorted(by: { $0.endTime < $1.endTime }) }
        return allSessions
            .filter { timeBox.contains($0.endTime) }
            .sorted(by: { $0.endTime < $1.endTime })
    }
    
    /// Builds charged energy data grouped by time period.
    /// - Parameter timeBox: The time box for filtering sessions.
    /// - Returns: A dictionary of energy data grouped by period key.
    @MainActor
    func chargedEnergyPerPeriod(in timeBox: TimeBox) -> [String: [EnergyData]] {
        var result = [String: [EnergyData]]()
        
        for plan in aggregateFromPlans({ [$0] }) {
            let chargedEnergyByPeriod = plan.chargedEnergy(in: timeBox, groupingKey: false)
            for (key, energy) in chargedEnergyByPeriod {
                let energyData = EnergyData(
                    legendLabel: plan.descriptionShortNoCar,
                    chargedEnergy: energy,
                    displayColor: plan.displayColor
                )
                result[key, default: []].append(energyData)
            }
        }
        
        return result.mapValues { $0.sorted() }
    }
    
    /// Returns charged energy data with optional grouping by time period.
    /// - Parameters:
    ///   - timeBox: The time box for filtering sessions.
    ///   - grouped: If true, returns data grouped by period; otherwise returns a flat array.
    /// - Returns: Either a flat array of EnergyData or a dictionary grouped by period.
    @MainActor
    func chargedEnergy(in timeBox: TimeBox, grouped: Bool = false) -> [EnergyData] {
        guard !grouped else {
            // For grouped access, use chargedEnergyPerPeriod instead
            return chargedEnergyPerPeriod(in: timeBox).values.flatMap { $0 }.sorted()
        }
        
        return aggregateFromPlans { [$0] }.map { plan in
            EnergyData(
                legendLabel: plan.descriptionShortNoCar,
                chargedEnergy: plan.totalChargedEnergy(in: timeBox),
                displayColor: plan.displayColor
            )
        }.sorted()
    }
    
    @MainActor
    func chargingCost(in timeBox: TimeBox, modelContext: ModelContext) async -> [CostData] {
        let plans = aggregateFromPlans { [$0] }
        var result = [CostData]()
        for plan in plans {
            let cost = await plan.totalChargingCost(in: timeBox, modelContext: modelContext)
            if cost.direct.amount > 0 {
                result.append(CostData(
                    legendLabel: plan.descriptionShortNoCar,
                    cost: cost.direct,
                    displayColor: plan.displayColor
                ))
            }
            if cost.indirect.amount > 0 {
                result.append(CostData(
                    legendLabel: plan.descriptionShortNoCar,
                    cost: cost.indirect,
                    displayColor: plan.displayColor
                ))
            }
        }
        return result.sorted()
    }
    
    @MainActor
    func specificCost(in timeBox: TimeBox, modelContext: ModelContext) async -> Cost? {
        let allSessions = aggregateFromPlans { $0.chargingSessions(in: timeBox) }
        var totalChargedEnergyKWh: Double = 0
        var totalChargingCost: Cost = Cost(amount: 0)
        var saveModelContext = false
        for session in allSessions {
            if session.chargedEnergyKWh == 0 { continue }
            var totalCost = session.totalChargingCost
            if totalCost.amount == 0, let estimatedRealCost = session.estimatedRealCost {
                totalCost += estimatedRealCost
            } else {
                // Try to estimate the cost based on the charging cost plan
                do {
                    session.estimatedRealCost = try await session.estimateRealCost(modelContext: modelContext).cost
                    totalCost += session.estimatedRealCost ?? .init(amount: 0)
                    saveModelContext = true
                } catch {
                    // Ignore estimation errors, as we ignore sessions with zero cost anyway
                }
            }
            if totalCost.amount == 0 { continue }
            
            // Add the session energy and cost
            totalChargedEnergyKWh += session.chargedEnergyKWh
            totalChargingCost += totalCost
        }
        
        // Save if necessary
        if saveModelContext {
            try? modelContext.save()
        }
        
        if totalChargedEnergyKWh == 0 { return nil }
        return Cost(amount: totalChargingCost.amount / totalChargedEnergyKWh)
    }
    
    @MainActor
    func consumptionData(in timeBox: TimeBox, modelContext: ModelContext) -> ConsumptionData? {
        let plans = aggregateFromPlans { [$0] }
        guard !plans.isEmpty else { return nil }
        let chargingSessions = chargingSessions(in: timeBox)
        guard !chargingSessions.isEmpty else { return nil }
        
        return try? ConsumptionData(modelContext: modelContext, timeBox: timeBox, relatedPlans: plans, sessions: chargingSessions)
    }
    
    @MainActor
    func averageEnergyPerPercentPoint(in timeBox: TimeBox? = nil) -> Measurement<UnitEnergy>? {
        let chargingSessions = self.chargingSessions(in: timeBox)
        let sessionsWithPercentAndEnergy = chargingSessions.filter { session in
            if let initial = session.initialSOC, let final = session.finalSOC {
                return final > initial && session.chargedEnergyKWh > 0
            }
            return false
        }

        let values: [Double] = sessionsWithPercentAndEnergy.compactMap { session in
            guard let initial = session.initialSOC, let final = session.finalSOC, final > initial else { return nil }
            let percentDiff = final - initial
            if percentDiff == 0 { return nil }
            return session.chargedEnergyKWh / percentDiff
        }

        guard !values.isEmpty else {
            // Return 0 kWh per percent point if no valid sessions
            return nil
        }

        let average = values.reduce(0, +) / Double(values.count)
        return Measurement(value: average, unit: UnitEnergy.kilowattHours)
    }
}

