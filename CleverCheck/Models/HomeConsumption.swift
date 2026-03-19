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
        case home = "Home consumption"
        case homeRefunded = "Refunded home consumption"
        case homeDiscount = "Discount on home consumption"
        case charging = "Charging"
        case chargingRefunded = "Refunded charging"
        case chargingDiscount = "Discount on charging"
        
        var description: String {
            NSLocalizedString(self.rawValue, comment: "")
        }
    }
    
    var id: UUID = UUID()
    var name: String = ""
    var validFrom: Date = Date.now.startOfMonth
    var validUntil: Date = Date.now.endOfMonth
    var consumptionKWh: Double = 0.0
    var consumptionIncludedElsewhere: Bool = false
    var consumptionType: ConsumptionType = ConsumptionType.home
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
        consumptionType: ConsumptionType = .home,
        associatedLocation: Location? = nil,
        comment: String? = nil
    ) {
        self.name = name
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.consumptionKWh = consumption.converted(to: .kilowattHours).value
        self.consumptionIncludedElsewhere = consumptionIncludedElsewhere
        self.consumptionType = consumptionType
        self.associatedLocation = associatedLocation
        if let comment {
            self.comment = comment
        }
    }
    
    /// Returns the consumption for the home consumption, either using the entered consumption or the consumption from related charging sessions. If the consumption is marked as included elsewhere and includeIfIncludedElsewhere is false, 0 is returned.
    /// - Parameters:
    ///   - includeIfIncludedElsewhere: If true, the consumption is returned even if it is marked as included elsewhere.
    ///   - useRelatedConsumptions: If true, the consumption from related charging sessions is used instead of the entered consumption. If no related charging sessions are available, the entered consumption is used.
    /// - Returns: The consumption as a Measurement<UnitEnergy>.
    func consumption(includeIfIncludedElsewhere: Bool, useRelatedConsumptions: Bool) -> Measurement<UnitEnergy> {
        if consumptionIncludedElsewhere && !includeIfIncludedElsewhere {
            return Measurement<UnitEnergy>(value: 0.0, unit: UserSettings.shared.energyUnit)
        } else {
            return useRelatedConsumptions ? (consumptionFromRelatedChargingSessions ?? consumption) : consumption
        }
    }
    
    /// Returns the consumption per month for the home consumption, either using the entered consumption or the consumption from related charging sessions. If the consumption is marked as included elsewhere and includeIfIncludedElsewhere is false, an empty dictionary is returned.
    /// - Parameters:
    ///   - includeIfIncludedElsewhere: If true, the consumption is returned even if it is marked as included elsewhere.
    ///   - useRelatedConsumptions: If true, the consumption from related charging sessions is used instead of the entered consumption.
    /// - Returns: A dictionary with month keys and consumption values.
    func consumptionPerMonth(includeIfIncludedElsewhere: Bool, useRelatedConsumptions: Bool) -> [String: Measurement<UnitEnergy>] {
        if consumptionIncludedElsewhere && !includeIfIncludedElsewhere {
            return [:]
        }
        
        let totalConsumption = consumption(includeIfIncludedElsewhere: includeIfIncludedElsewhere, useRelatedConsumptions: useRelatedConsumptions).converted(to: .kilowattHours).value
        
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
        
        // Convert the consumptions to Measurement<UnitEnergy>
        var consumptionPerMonthWithUnit: [String: Measurement<UnitEnergy>] = [:]
        for (monthKey, consumption) in consumptionPerMonth {
            consumptionPerMonthWithUnit[monthKey] = Measurement<UnitEnergy>(value: consumption, unit: .kilowattHours)
        }
        return consumptionPerMonthWithUnit
    }
    
    /// Calculates the total consumption for a specific month.
    /// - Parameters:
    ///   - monthKey: The month identifier in "yyyy-MM" format.
    ///   - includeIfIncludedElsewhere: Indicates whether to include consumption that is marked as included elsewhere.
    ///   - useRelatedConsumptions: If true, the consumption from related charging sessions is used instead of the entered consumption. If no charging sessions are availale, the entered consumption is used.
    /// - Returns: The total consumption for the specified month as a Double.
    func consumptionForMonth(monthKey: String, includeIfIncludedElsewhere: Bool, useRelatedConsumptions: Bool) -> Measurement<UnitEnergy> {
        return consumptionPerMonth(includeIfIncludedElsewhere: includeIfIncludedElsewhere, useRelatedConsumptions: useRelatedConsumptions)[monthKey] ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit)
    }
    
    /// Calculates the total cost for the home consumption over its entire duration, adding up all price elements.
    /// - Parameter includingVAT: Indicates whether to calculate cost without VAT or with VAT. Default is true (including VAT).
    /// - Parameter useRelatedConsumptions: If true, the consumption from related charging sessions is used instead of the entered consumption. If no charging sessions are availale, the entered consumption is used.
    /// - Returns: The total cost as Cost.
    func totalCost(includingVAT: Bool = true, useRelatedConsumptions: Bool) -> Cost {
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
                let consumption = useRelatedConsumptions ? (consumptionFromRelatedChargingSessions ?? self.consumption) : self.consumption
                let convertedConsumption = consumption.converted(to: energyUnit).value
                return $0 + ($1.getConvertedCost(includingVAT: includingVAT).amount * convertedConsumption)
            }
        }
        
        return .init(amount: value)
    }
    
    /// Calculates the total cost per month for the duration of the home consumption.
    /// - Parameter includingVAT: Indicates whether to include VAT or not.
    /// - Parameter useRelatedConsumptions: If true, the consumption from related charging sessions is used instead of the entered consumption for calculating byConsumption price elements. If no charging sessions are availale, the entered consumption is used.
    /// - Returns: A dictionary where keys are month identifiers in "yyyy-MM" format and values are the corresponding costs for that month.
    func totalCostPerMonth(includingVAT: Bool = true, useRelatedConsumptions: Bool) -> [String: Cost] {
        let totalCost = totalCost(includingVAT: includingVAT, useRelatedConsumptions: useRelatedConsumptions)
        
        // Determine the number of days for each of the covered months, calculate each month's cost portion, and store them in a dictionary
        var costPerMonth: [String: Double] = [:]
        for (monthKey, daysInMonth) in daysPerMonth {
            // Determine the cost portion in this month
            costPerMonth[monthKey] = (totalCost.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0) / Double(numberOfDays) * Double(daysInMonth)
        }
        
        // Normalize the costs to ensure they sum up to the total cost (to avoid rounding issues)
        let sumOfCosts = costPerMonth.values.reduce(0, +)
        if sumOfCosts != totalCost.amount {
            let difference = totalCost.amount - sumOfCosts
            if let firstKey = costPerMonth.keys.first {
                costPerMonth[firstKey]! += difference
            }
        }
        
        // Convert the costs to Cost type
        var costPerMonthWithCostType: [String: Cost] = [:]
        for (monthKey, costs) in costPerMonth {
            costPerMonthWithCostType[monthKey] = .init(amount: costs, currency: UserSettings.shared.currencyIdentifier)
        }
        return costPerMonthWithCostType
    }

    /// Calculates the total cost for a specific month.
    /// - Parameters:
    ///   - monthKey: The month identifier in "yyyy-MM" format.
    ///   - includingVAT: Indicates whether to include VAT or not.
    ///   - useRelatedConsumptions: If true, the consumption from related charging sessions is used instead of the entered consumption for calculating byConsumption price elements. If no charging sessions are availale, the entered consumption is used.
    /// - Returns: The total cost for the specified month.
    func totalCostForMonth(monthKey: String, includingVAT: Bool = true, useRelatedConsumptions: Bool) -> Cost {
        totalCostPerMonth(includingVAT: includingVAT, useRelatedConsumptions: useRelatedConsumptions)[monthKey] ?? .init(amount: 0.0)
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
    
    private func sumOfPriceElements(_ priceElements: [PriceElement]) -> Cost {
        .init(
            amount: priceElements.reduce(0.0) { $0 + $1.getConvertedCost(includingVAT: UserSettings.shared.displayGrossPrices).amount }
        )
    }
    
    static func < (lhs: HomeConsumption, rhs: HomeConsumption) -> Bool {
        lhs.validUntil < rhs.validUntil
    }
}

