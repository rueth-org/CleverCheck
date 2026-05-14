//
//  HomeConsumption.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 30/11/2025.
//

import Foundation
import SwiftData

@Model
final class HomeConsumption: Comparable {
    enum ConsumptionType: String, Codable, CustomStringConvertible, CaseIterable {
        case total = "Total consumption"
        case home = "Home consumption"
        case homeRefunded = "Refunded home consumption"
        case homeDiscount = "Discount on home consumption"
        case charging = "Charging"
        case chargingRefunded = "Refunded charging"
        case chargingDiscount = "Discount on charging"
        case refundingOtherPlan = "Refunding for other plan"
        
        var description: String {
            NSLocalizedString(self.rawValue, comment: "")
        }
    }
    
    var id: UUID = UUID()
    var name: String = ""
    var validFrom: Date = Date.now.startOfMonth
    var validUntil: Date = Date.now.endOfMonth
    var consumptionKWh: Double = 0.0
    var consumptionType: ConsumptionType = ConsumptionType.total
    var associatedLocation: Location?
    var defaultToEnteredConsumption: Bool = true
    var comment: String = ""
    
    @Relationship(deleteRule: .cascade, inverse: \PriceElement.homeConsumption)
    var priceElements: [PriceElement]?
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingSession.relatedHomeConsumption)
    var chargingSessions: [ChargingSession]?
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingSession.relatedRefundingHomeConsumption)
    var refundedChargingSessions: [ChargingSession]?
    
    var consumptionFromRelatedChargingSessions: Measurement<UnitEnergy>? {
        if let chargingSessions, !chargingSessions.isEmpty {
            let consumptions = chargingSessions.compactMap { $0.chargedEnergyKWh }
            let totalConsumption = consumptions.reduce(0.0, +)
            return Measurement<UnitEnergy>(value: totalConsumption, unit: .kilowattHours)
        } else {
            return nil
        }
    }
    
    var consumptionFromRelatedRefundedChargingSessions: Measurement<UnitEnergy>? {
        if let refundedChargingSessions, !refundedChargingSessions.isEmpty {
            let consumptions = refundedChargingSessions.compactMap { $0.chargedEnergyKWh }
            let totalConsumption = consumptions.reduce(0.0, +)
            return Measurement<UnitEnergy>(value: totalConsumption, unit: .kilowattHours)
        } else {
            return nil
        }
    }
    
    @Transient var consumption: Measurement<UnitEnergy> {
        get {
            return Measurement<UnitEnergy>(value: consumptionKWh, unit: .kilowattHours)
        }
        set {
            consumptionKWh = newValue.converted(to: .kilowattHours).value
        }
    }
    
    var sumOfPriceElementsByConsumption: Cost {
        if let priceElements {
            let specificPriceElements = priceElements.filter {
                if case .byConsumption(_) = $0.type { return true } else { return false }
            }
            return sumOfPriceElements(specificPriceElements)
        }
        return .init(amount: 0.0)
    }
    
    var sumOfPriceElementsDaily: Cost {
        if let priceElements {
            let specificPriceElements = priceElements.filter {
                if case .daily = $0.type { return true } else { return false }
            }
            return sumOfPriceElements(specificPriceElements)
        }
        return .init(amount: 0.0)
    }
    
    var sumOfPriceElementsOnce: Cost {
        if let priceElements {
            let specificPriceElements = priceElements.filter {
                if case .once = $0.type { return true } else { return false }
            }
            return sumOfPriceElements(specificPriceElements)
        }
        return .init(amount: 0.0)
    }
    
    var description: String {
        if associatedLocation != nil {
            return "\(name) (\(associatedLocation!.name))"
        } else {
            return "\(name)"
        }
    }
    
    var descriptionWithDate: String {
        let dateFormatter = DateFormatter().shortMonthYear
        return "\(description) (\(dateFormatter.string(from: validUntil)))"
    }
    
    /// Calculates the number of days covered in each month within the validFrom to validUntil range.
    private var daysPerMonth: [String: Int] {
        let calendar = Calendar.current
        
        // Determine the number of days for each of the covered months, and store them in a dictionary
        var daysPerMonth: [String: Int] = [:]
        var currentDate = validFrom
        while currentDate <= validUntil {
            let monthKey = UserSettings.shared.groupingDateFormatter.string(from: currentDate)
            
            // Determine the start of the month and next month
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate))!
            guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                break
            }
            
            // Determine if currentDate is later than the first day of the month
            let monthStartDate = currentDate > startOfMonth ? currentDate : startOfMonth
            
            // Determine if validUntil is earlier than the last day of the month
            let monthEndDate = validUntil < endOfMonth ? validUntil : endOfMonth.addingTimeInterval(-1)
            
            // Calculate the number of days in this month portion
            let components = calendar.dateComponents([.day], from: monthStartDate, to: monthEndDate)
            daysPerMonth[monthKey] = (components.day ?? 0) + 1
            
            // Move to the next month
            currentDate = endOfMonth
        }
        
        return daysPerMonth
    }
    
    private var numberOfDays: Int {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: validFrom)
        let endDate = calendar.startOfDay(for: validUntil)
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }
    
    init(
        name: String,
        validFrom: Date,
        validUntil: Date,
        consumption: Measurement<UnitEnergy>,
        consumptionType: ConsumptionType = .total,
        associatedLocation: Location? = nil,
        comment: String? = nil
    ) {
        self.name = name
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.consumptionKWh = consumption.converted(to: .kilowattHours).value
        self.consumptionType = consumptionType
        self.associatedLocation = associatedLocation
        if let comment {
            self.comment = comment
        }
    }
    
    /// Returns the consumption for the home consumption, either using the entered consumption or the consumption from related charging sessions.
    /// - Parameter useRelatedConsumptions: If true, the consumption from related charging sessions is used instead of the entered consumption. If no related charging sessions are available and defaultToEnteredConsumption is true, the entered consumption is returned, otherwise 0 is returned.
    /// - Returns: The consumption as a Measurement<UnitEnergy>.
    private func consumption(useRelatedConsumptions: Bool, reduceTotalBy: Measurement<UnitEnergy>) -> Measurement<UnitEnergy> {
        if useRelatedConsumptions {
            if let consumptionFromRelatedChargingSessions {
                return max(consumptionFromRelatedChargingSessions - reduceTotalBy, .init(value: 0.0, unit: .kilowattHours)) // Ensure consumption is not negative
            } else {
                return defaultToEnteredConsumption ? max(consumption - reduceTotalBy, .init(value: 0.0, unit: .kilowattHours)) : .init(value: 0.0, unit: .kilowattHours)
            }
        } else {
            return max(consumption - reduceTotalBy, .init(value: 0.0, unit: .kilowattHours)) // Ensure consumption is not negative
        }
    }
    
    func totalConsumption(useRelatedConsumptions: Bool, reduceTotalBy: Measurement<UnitEnergy>?) -> (home: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>) {
        let reduceTotalBy = reduceTotalBy?.converted(to: .kilowattHours) ?? .init(value: 0.0, unit: .kilowattHours)
        switch consumptionType {
        case .total:
            let chargingConsumptionKWh = consumptionFromRelatedChargingSessions?.converted(to: .kilowattHours).value ?? 0.0
            let homeConsumptionKWh = max(consumptionKWh - reduceTotalBy.value - chargingConsumptionKWh, 0.0) // Ensure home consumption is not negative
            return (home: .init(value: homeConsumptionKWh, unit: .kilowattHours), charging: .init(value: chargingConsumptionKWh, unit: .kilowattHours))
        case .home, .homeDiscount, .homeRefunded:
            return (home: consumption(useRelatedConsumptions: useRelatedConsumptions, reduceTotalBy: reduceTotalBy), charging: .init(value: 0.0, unit: .kilowattHours))
        case .charging, .chargingDiscount, .chargingRefunded, .refundingOtherPlan:
            return (home: .init(value: 0.0, unit: .kilowattHours), charging: consumption(useRelatedConsumptions: useRelatedConsumptions, reduceTotalBy: reduceTotalBy))
        }
    }
    
    func consumptionPerMonth(useRelatedConsumptions: Bool, reduceTotalBy: Measurement<UnitEnergy>?) -> [String: (home: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>)] {
        let totalConsumption = totalConsumption(useRelatedConsumptions: useRelatedConsumptions, reduceTotalBy: reduceTotalBy)
        return distributeConsumption(totalConsumption)
    }
    
    private func distributeConsumption(_ totalConsumption: (home: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>)) -> [String: (home: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>)] {
        let numberOfDays = self.numberOfDays
        guard numberOfDays > 0 else {
            // If no days, return the total consumption as is for the validUntil month
            let monthKey = UserSettings.shared.groupingDateFormatter.string(from: validUntil)
            return [monthKey: totalConsumption]
        }
        
        let homeTotalKWh = totalConsumption.home.converted(to: .kilowattHours).value
        let chargingTotalKWh = totalConsumption.charging.converted(to: .kilowattHours).value
        
        // Determine the number of days for each of the covered months, calculate each month's cost portion, and store them in a dictionary
        var consumptionPerMonthKWh: [String: (home: Double, charging: Double)] = [:]
        for (monthKey, daysInMonth) in daysPerMonth {
            // Determine the share in this month
            let monthShare = Double(daysInMonth) / Double(numberOfDays)
            consumptionPerMonthKWh[monthKey] = (home: homeTotalKWh * monthShare, charging: chargingTotalKWh * monthShare)
        }
        
        // Normalize the consumptions to ensure they sum up to the total consumption (to avoid rounding issues)
        let sumOfConsumptions = consumptionPerMonthKWh.values.reduce(0) { $0 + $1.home + $1.charging }
        if sumOfConsumptions != homeTotalKWh + chargingTotalKWh {
            let difference = (homeTotalKWh + chargingTotalKWh) - sumOfConsumptions
            if let firstKey = consumptionPerMonthKWh.keys.first {
                let homeShare = homeTotalKWh / (homeTotalKWh + chargingTotalKWh)
                consumptionPerMonthKWh[firstKey]!.home += difference * homeShare
                consumptionPerMonthKWh[firstKey]!.charging += difference * (1 - homeShare)
            }
        }
        
        // Convert the consumptions to Measurement type
        var consumptionPerMonthWithUnit: [String: (home: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>)] = [:]
        for (monthKey, consumption) in consumptionPerMonthKWh {
            consumptionPerMonthWithUnit[monthKey] = (home: Measurement<UnitEnergy>(value: consumption.home, unit: .kilowattHours), charging: Measurement<UnitEnergy>(value: consumption.charging, unit: .kilowattHours))
        }
        return consumptionPerMonthWithUnit
    }
    
    /// Calculates the total cost for the home consumption over its entire duration, adding up all price elements.
    /// - Parameter includingVAT: Indicates whether to calculate cost without VAT or with VAT. Default is true (including VAT).
    /// - Parameter useRelatedConsumptions: If true, the consumption from related charging sessions is used instead of the entered consumption. If no charging sessions are availale, the entered consumption is used.
    /// - Returns: The total cost as Cost.
    private func cost(includingVAT: Bool = true, useRelatedConsumptions: Bool, reduceTotalBy: Cost) -> Cost {
        guard let priceElements else {
            return .init(amount: 0.0)
        }
        
        let value = priceElements.reduce(0.0) {
            switch $1.type {
            case .daily:
                return $0 + ($1.getConvertedCost(includingVAT: includingVAT).amount * Double(numberOfDays))
            case .once:
                return $0 + $1.getConvertedCost(includingVAT: includingVAT).amount
            case .byConsumption(let energyUnitSymbol):
                guard let energyUnit = UserSettings.shared.energyUnit(for: energyUnitSymbol) else {
                    fatalError("Unknown energy unit symbol: \(energyUnitSymbol)")
                }
                let consumption = consumption(useRelatedConsumptions: useRelatedConsumptions, reduceTotalBy: .init(value: 0.0, unit: .kilowattHours)).converted(to: energyUnit).value // Don't reduce the total, we subtract reduceTotalBy at the end
                return $0 + ($1.getConvertedCost(includingVAT: includingVAT).amount * consumption)
            }
        }
        
        return .init(amount: value) + reduceTotalBy // reduceTotalBy is added as it's a negative value, so we need to add it to subtract if from the total cost
    }
    
    func totalCost(includingVAT: Bool = true, useRelatedConsumptions: Bool, reduceTotalBy: (consumption: Measurement<UnitEnergy>, cost: Cost)?) -> (home: Cost, charging: Cost) {
        let reduceTotalBy = reduceTotalBy ?? (consumption: .init(value: 0.0, unit: .kilowattHours), cost: .init(amount: 0.0))
        switch consumptionType {
        case .total:
            let totalCost = cost(includingVAT: includingVAT, useRelatedConsumptions: false, reduceTotalBy: reduceTotalBy.cost).converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0
            guard totalCost > 0 else {
                // If no total cost, there can't be any monthly cost
                return (home: .init(amount: 0.0), charging: .init(amount: 0.0))
            }
            
            let totalConsumption = totalConsumption(useRelatedConsumptions: useRelatedConsumptions, reduceTotalBy: reduceTotalBy.consumption)
            let fullConsumptionKWh = totalConsumption.home.converted(to: .kilowattHours).value + totalConsumption.charging.converted(to: .kilowattHours).value
            guard fullConsumptionKWh > 0 else {
                // If no consumption, there can't be any related charging cost
                return (home: .init(amount: totalCost), charging: .init(amount: 0.0))
            }
            
            let homeShare = totalConsumption.home.value / fullConsumptionKWh
            return (home: .init(amount: totalCost * homeShare), charging: .init(amount: totalCost * (1 - homeShare)))
        case .home, .homeDiscount, .homeRefunded:
            // These are home consumptions, so no charging costs should be included
            let totalCost = cost(includingVAT: includingVAT, useRelatedConsumptions: useRelatedConsumptions, reduceTotalBy: reduceTotalBy.cost)
            return (home: totalCost, charging: .init(amount: 0.0))
        case .charging, .chargingDiscount, .chargingRefunded, .refundingOtherPlan:
            // These are charging consumptions, so the full cost should be included as charging cost
            let totalCost = cost(includingVAT: includingVAT, useRelatedConsumptions: useRelatedConsumptions, reduceTotalBy: reduceTotalBy.cost)
            return (home: .init(amount: 0.0), charging: totalCost)
        }
    }
    
    func costPerMonth(
        includingVAT: Bool = true,
        useRelatedConsumptions: Bool,
        reduceTotalBy: (consumption: Measurement<UnitEnergy>, cost: Cost)?
    ) -> [String: (home: Cost, charging: Cost)] {
        let totalCost = totalCost(includingVAT: includingVAT, useRelatedConsumptions: useRelatedConsumptions, reduceTotalBy: reduceTotalBy)
        return distributeCost(totalCost)
    }
    
    private func distributeCost(_ totalCost: (home: Cost, charging: Cost)) -> [String: (home: Cost, charging: Cost)] {
        let numberOfDays = self.numberOfDays
        guard numberOfDays > 0 else {
            // If no days, return the total cost as is for the validUntil month
            let monthKey = UserSettings.shared.groupingDateFormatter.string(from: validUntil)
            return [monthKey: totalCost]
        }
        
        // Determine the number of days for each of the covered months, calculate each month's cost portion, and store them in a dictionary
        var costPerMonth: [String: (home: Double, charging: Double)] = [:]
        for (monthKey, daysInMonth) in daysPerMonth {
            // Determine the cost portion in this month
            let monthShare = Double(daysInMonth) / Double(numberOfDays)
            costPerMonth[monthKey] = (
                home: (totalCost.home.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0) * monthShare,
                charging: (totalCost.charging.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0) * monthShare
            )
        }
        
        // Normalize the costs to ensure they sum up to the total cost (to avoid rounding issues)
        let sumOfCosts = costPerMonth.values.reduce(0) { $0 + $1.home + $1.charging }
        let totalCostAmount = (totalCost.home.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0) + (totalCost.charging.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0)
        if sumOfCosts != totalCostAmount {
            let difference = totalCostAmount - sumOfCosts
            if let firstKey = costPerMonth.keys.first {
                let homeShare = (totalCost.home.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0) / totalCostAmount
                costPerMonth[firstKey]!.home += difference * homeShare
                costPerMonth[firstKey]!.charging += difference * (1 - homeShare)
            }
        }
        
        // Convert the costs to Cost type
        var costPerMonthWithCostType: [String: (home: Cost, charging: Cost)] = [:]
        for (monthKey, costs) in costPerMonth {
            costPerMonthWithCostType[monthKey] = (home: .init(amount: costs.home), charging: .init(amount: costs.charging))
        }
        return costPerMonthWithCostType
    }
    
    func possibleChargingSessions(ignoreConsumptionType: Bool, modelContext: ModelContext, showRefundedSessions: Bool) -> [ChargingSession]? {
        if let chargingSessions = try? modelContext.fetch(FetchDescriptor<ChargingSession>(
            predicate: #Predicate { session in
                validFrom <= session.endTime && session.endTime <= validUntil
            }
        )) {
            if chargingSessions.isEmpty {
                return nil
            } else {
                // Match the possible plan types
                var planType: ChargingCostPlan.PlanType? = nil
                if !ignoreConsumptionType {
                    if showRefundedSessions {
                        planType = .refunded
                    } else {
                        switch consumptionType {
                        case .refundingOtherPlan:
                            planType = .refunded
                        case .chargingDiscount:
                            planType = .homeDiscounted
                        case .charging:
                            planType = .homeConsumption
                        default:
                            planType = nil
                        }
                    }
                }
                
                var candidates = [ChargingSession]()
                if let planType {
                    candidates = chargingSessions.filter({ session in
                        session.chargingCostPlan?.planType == planType &&
                        (consumptionType == .chargingRefunded ? session.chargingCostPlan?.includedInOtherPlan?.charger?.location?.id == self.associatedLocation?.id : session.chargingCostPlan?.charger?.location?.id == self.associatedLocation?.id)
                    })
                } else {
                    // We return all sessions for the location
                    candidates = chargingSessions.filter({ session in
                        (consumptionType == .chargingRefunded ? session.chargingCostPlan?.includedInOtherPlan?.charger?.location?.id == self.associatedLocation?.id : session.chargingCostPlan?.charger?.location?.id == self.associatedLocation?.id)
                    })
                }
                return candidates.sorted(by: { $0.endTime < $1.endTime })
            }
        } else {
            return nil
        }
    }
    
    /// Simulates the cost of home consumption for a given time range and consumption and a given price per kWh. Only price elements not excluded from simulation are used.
    /// - Parameters:
    ///   - consumptionKWh: The consumption in kWh to simulate the cost for. This allows to simulate the cost for different consumption values than the one entered in the home consumption, e.g. for a future month or to see how the cost would have changed with a different consumption.
    ///   - pricePerKWh: The price per kWh to use for the consumption.
    ///   - start: The start date of the simulation period.
    ///   - end: The end date of the simulation period.
    /// - Returns: The simulated cost for the given consumption and time range.
    func simulateCost(of consumptionKWh: Double, with pricePerKWh: Cost, durationInMinutes: Double) -> Cost {
        // Calculate the proportion of the time range (start to end) within the validFrom to validUntil range
        let duration = durationInMinutes * 60 // Convert minutes to seconds
        let totalDuration = validUntil.timeIntervalSince(validFrom)
        guard totalDuration > 0 else {
            return .init(amount: 0.0)
        }
        let proportion = duration / totalDuration
        
        // Filter the price elements to be included in the simulation
        guard let priceElements else {
            return .init(amount: 0.0)
        }
        let includedPriceElements = priceElements.filter { $0.excludeFromSimulation == false }
        
        // Filter the included price elements by those with types .once and .daily
        let sumOfPriceElementsOnce = sumOfPriceElements(includedPriceElements.filter {
            if case .once = $0.type { return true } else { return false }
        })
        let sumOfPriceElementsDaily = sumOfPriceElements(includedPriceElements.filter {
            if case .daily = $0.type { return true } else { return false }
        })
        
        // Calculate the fixed costs (once + daily * number of days)
        let fixedCosts = sumOfPriceElementsOnce.amount + sumOfPriceElementsDaily.amount * Double(numberOfDays)
        
        // Calculate the variable cost
        let sumOfPriceElementsSpecific = sumOfPriceElements(includedPriceElements.filter {
            if case .byConsumption(_) = $0.type { return true } else { return false }
        })
        
        // Add the given price per kWh
        let sumOfPriceElementsByConsumption = sumOfPriceElementsSpecific + pricePerKWh
        
        // Calculate simulated cost
        let simulatedCost = fixedCosts * proportion + sumOfPriceElementsByConsumption.amount * consumptionKWh
        return .init(amount: simulatedCost)
    }
    
    private func sumOfPriceElements(_ priceElements: [PriceElement]) -> Cost {
        .init(
            amount: priceElements.reduce(0.0) { $0 + $1.getConvertedCost(includingVAT: UserSettings.shared.displayGrossPrices).amount }
        )
    }
    
    static func < (lhs: HomeConsumption, rhs: HomeConsumption) -> Bool {
        lhs.validUntil < rhs.validUntil
    }
}

