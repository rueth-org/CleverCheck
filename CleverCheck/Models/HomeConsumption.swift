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
    var id: UUID = UUID()
    var name: String = ""
    var validFrom: Date = Date.now.startOfMonth
    var validUntil: Date = Date.now.endOfMonth
    var consumptionKWh: Double = 0.0
    var consumptionIncludedElsewhere: Bool = false
    var associatedLocation: Location?
    var comment: String = ""
    
    @Relationship(deleteRule: .cascade, inverse: \PriceElement.homeConsumption)
    var priceElements: [PriceElement]?
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingSession.relatedHomeConsumption)
    var chargingSessions: [ChargingSession]?
    
    var consumptionFromRelatedChargingSessions: Measurement<UnitEnergy>? {
        if let chargingSessions, !chargingSessions.isEmpty {
            let consumptions = chargingSessions.compactMap { $0.chargedEnergyKWh }
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
    
    /// Calculates the number of days covered in each month within the validFrom to validUntil range.
    var daysPerMonth: [String: Int] {
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
    
    var netConsumptionPerMonth: [String: Double] {
        var grossConsumptionPerMonth = consumptionPerMonth(includeIfIncludedElsewhere: true)
        if consumptionIncludedElsewhere {
            for (monthKey, consumption) in grossConsumptionPerMonth {
                grossConsumptionPerMonth[monthKey] = -consumption
            }
        }
        return grossConsumptionPerMonth
    }
    
    var sumOfPriceElementsByConsumption: Double {
        if let priceElements {
            let specificPriceElements = priceElements.filter {
                if case .byConsumption(_) = $0.type { return true } else { return false }
            }
            return sumOfPriceElements(specificPriceElements)
        }
        return 0.0
    }
    
    var sumOfPriceElementsDaily: Double {
        if let priceElements {
            let specificPriceElements = priceElements.filter {
                if case .daily = $0.type { return true } else { return false }
            }
            return sumOfPriceElements(specificPriceElements)
        }
        return 0.0
    }
    
    var sumOfPriceElementsOnce: Double {
        if let priceElements {
            let specificPriceElements = priceElements.filter {
                if case .once = $0.type { return true } else { return false }
            }
            return sumOfPriceElements(specificPriceElements)
        }
        return 0.0
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
    
    var numberOfDays: Int {
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
        consumptionIncludedElsewhere: Bool,
        associatedLocation: Location? = nil,
        comment: String? = nil
    ) {
        self.name = name
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.consumptionKWh = consumption.converted(to: .kilowattHours).value
        self.consumptionIncludedElsewhere = consumptionIncludedElsewhere
        self.associatedLocation = associatedLocation
        if let comment {
            self.comment = comment
        }
    }
    
    func totalConsumption(includeIfIncludedElsewhere: Bool = false) -> Measurement<UnitEnergy> {
        if consumptionIncludedElsewhere && !includeIfIncludedElsewhere {
            return Measurement<UnitEnergy>(value: 0.0, unit: UserSettings.shared.energyUnit)
        } else {
            return consumption
        }
    }
    
    func consumptionPerMonth(includeIfIncludedElsewhere: Bool = false) -> [String: Double] {
        if consumptionIncludedElsewhere && !includeIfIncludedElsewhere {
            return [:]
        }
        
        let totalConsumption = totalConsumption(includeIfIncludedElsewhere: includeIfIncludedElsewhere).value
        
        // Determine the number of days for each of the covered months, calculate each month's consumption portion, and store them in a dictionary
        var consumptionPerMonth: [String: Double] = [:]
        for (monthKey, daysInMonth) in daysPerMonth {
            // Determine the consumption portion in this month
            consumptionPerMonth[monthKey] = totalConsumption / Double(numberOfDays) * Double(daysInMonth)
        }
        
        // Normalize the consumptions to ensure they sum up to the total consumption (to avoid rounding issues)
        let sumOfConsumptions = consumptionPerMonth.values.reduce(0, +)
        if sumOfConsumptions != totalConsumption {
            let difference = totalConsumption - sumOfConsumptions
            if let firstKey = consumptionPerMonth.keys.first {
                consumptionPerMonth[firstKey]! += difference
            }
        }
        
        return consumptionPerMonth
    }
    
    /// Calculates the total consumption for a specific month.
    /// - Parameters:
    ///   - monthKey: The month identifier in "yyyy-MM" format.
    ///   - includeIfIncludedElsewhere: Indicates whether to include consumption that is marked as included elsewhere. Default is false.
    /// - Returns: The total consumption for the specified month as a Double.
    func consumptionForMonth(monthKey: String, includeIfIncludedElsewhere: Bool = false) -> Double {
        return consumptionPerMonth(includeIfIncludedElsewhere: includeIfIncludedElsewhere)[monthKey] ?? 0.0
    }
    
    func netConsumptionForMonth(monthKey: String) -> Double {
        return netConsumptionPerMonth[monthKey] ?? 0.0
    }
    
    /// Calculates the total cost for the home consumption over its entire duration, adding up all price elements.
    /// - Parameter isGross: Indicates whether to calculate cost without VAT (isGross = false) or with VAT (isGross = true). Default is true (gross).
    /// - Parameter useConsumptionFromRelatedChargingSessions: If true, the consumption from related charging sessions is used instead of the entered consumption. If no charging sessions are availale, the entered consumption is used. Default is false.
    /// - Returns: The total cost as a (gross: Double, net: Double) tuple. The first value represents the sum of all positive price elements (gross), the second the sum of all postive and negative price elements (net).
    func totalCost(isGross: Bool = true, useConsumptionFromRelatedChargingSessions: Bool = false) -> (gross: Double, net: Double) {
        if priceElements == nil {
            return (0.0, 0.0)
        }
        
        let netValue = priceElements!.reduce(0.0) {
            switch $1.type {
            case .daily:
                return $0 + ($1.grossAmount * Double(numberOfDays))
            case .once:
                return $0 + $1.grossAmount
            case .byConsumption(let energyUnitSymbol):
                guard let energyUnit = UserSettings.shared.energyUnit(for: energyUnitSymbol) else {
                    fatalError("Unknown energy unit symbol: \(energyUnitSymbol)")
                }
                let consumption = useConsumptionFromRelatedChargingSessions ? (consumptionFromRelatedChargingSessions ?? self.consumption) : self.consumption
                let convertedConsumption = consumption.converted(to: energyUnit).value
                return $0 + ($1.grossAmount * convertedConsumption)
            }
        }
        
        let grossValue = priceElements!.reduce(0.0) {
            switch $1.type {
            case .daily:
                let value = $1.grossAmount * Double(numberOfDays)
                if value >= 0.0 {
                    return $0 + value
                } else {
                    return $0
                }
            case .once:
                let value = $1.grossAmount
                if value >= 0.0 {
                    return $0 + value
                } else {
                    return $0
                }
            case .byConsumption(let energyUnitSymbol):
                guard let energyUnit = UserSettings.shared.energyUnit(for: energyUnitSymbol) else {
                    fatalError("Unknown energy unit symbol: \(energyUnitSymbol)")
                }
                let consumption = useConsumptionFromRelatedChargingSessions ? (consumptionFromRelatedChargingSessions ?? self.consumption) : self.consumption
                let convertedConsumption = consumption.converted(to: energyUnit).value
                let value = $1.grossAmount * convertedConsumption
                if value >= 0.0 {
                    return $0 + value
                } else {
                    return $0
                }
            }
        }
        
        return (gross: grossValue, net: netValue)
    }
    
    /// Calculates the total cost per month for the duration of the home consumption.
    /// - Parameter isGross: Indicates whether to calculate gross or net costs. Default is true (gross).
    /// - Returns: A dictionary where keys are month identifiers in "yyyy-MM" format and values are the corresponding costs for that month.
    func totalCostPerMonth(isGross: Bool = true, useConsumptionFromRelatedChargingSessions: Bool = false) -> [String: (gross: Double, net: Double)] {
        let totalCost = totalCost(isGross: isGross, useConsumptionFromRelatedChargingSessions: useConsumptionFromRelatedChargingSessions)
        
        // Determine the number of days for each of the covered months, calculate each month's cost portion, and store them in a dictionary
        var costPerMonth: [String: (gross: Double, net: Double)] = [:]
        for (monthKey, daysInMonth) in daysPerMonth {
            // Determine the cost portion in this month
            costPerMonth[monthKey] = (
                gross: totalCost.gross / Double(numberOfDays) * Double(daysInMonth),
                net: totalCost.net / Double(numberOfDays) * Double(daysInMonth)
            )
        }
        
        // Normalize the gross costs to ensure they sum up to the total cost (to avoid rounding issues)
        let sumOfGrossCosts = costPerMonth.values.reduce(0) { $0 + $1.gross }
        if sumOfGrossCosts != totalCost.gross {
            let difference = totalCost.gross - sumOfGrossCosts
            if let firstKey = costPerMonth.keys.first {
                costPerMonth[firstKey]!.gross += difference
            }
        }
        
        // Normalize the net costs to ensure they sum up to the total cost (to avoid rounding issues)
        let sumOfNetCosts = costPerMonth.values.reduce(0) { $0 + $1.net }
        if sumOfNetCosts != totalCost.net {
            let difference = totalCost.net - sumOfNetCosts
            if let firstKey = costPerMonth.keys.first {
                costPerMonth[firstKey]!.net += difference
            }
        }
        
        return costPerMonth
    }

    /// Calculates the total cost for a specific month.
    /// - Parameters:
    ///   - monthKey: The month identifier in "yyyy-MM" format.
    ///   - isGross: Indicates whether to calculate gross or net costs. Default is true (gross).
    /// - Returns: The total cost for the specified month as a Double.
    func totalCostForMonth(monthKey: String, isGross: Bool = true, useConsumptionFromRelatedChargingSessions: Bool = false) -> (gross: Double, net: Double) {
        return totalCostPerMonth(isGross: isGross, useConsumptionFromRelatedChargingSessions: useConsumptionFromRelatedChargingSessions)[monthKey] ?? (0.0, 0.0)
    }
    
    func possibleChargingSessions(modelContext: ModelContext) -> [ChargingSession]? {
        if let chargingSessions = try? modelContext.fetch(FetchDescriptor<ChargingSession>(
            predicate: #Predicate { session in
                validFrom <= session.endTime && session.endTime <= validUntil
            }
        )) {
            if chargingSessions.isEmpty {
                return nil
            } else {
                let candidates = chargingSessions.filter({ session in
                    session.chargingCostPlan?.planType == .refunded &&
                    session.chargingCostPlan?.includedInOtherPlan?.charger?.location?.id == self.associatedLocation?.id
                })
                return candidates.sorted(by: { $0.endTime < $1.endTime })
            }
        } else {
            return nil
        }
    }
    
    private func sumOfPriceElements(_ priceElements: [PriceElement]) -> Double {
        priceElements.reduce(0.0) { $0 + $1.getAmount(isGross: UserSettings.shared.displayGrossPrices) }
    }
    
    static func < (lhs: HomeConsumption, rhs: HomeConsumption) -> Bool {
        lhs.validUntil < rhs.validUntil
    }
}

