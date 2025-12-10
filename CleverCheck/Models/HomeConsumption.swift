//
//  HomeConsumption.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 30/11/2025.
//

import Foundation
import SwiftData

@Model
final class HomeConsumption {
    var id: UUID
    var name: String
    var validFrom: Date
    var validUntil: Date
    var consumptionKWh: Double
    var associatedChargingLocation: ChargingLocation?
    
    @Relationship(deleteRule: .cascade, inverse: \PriceElement.homeConsumption)
    var priceElements: [PriceElement] = []
    
    @Transient var consumption: Measurement<UnitEnergy> {
        get {
            return Measurement<UnitEnergy>(value: consumptionKWh, unit: .kilowattHours)
        }
        set {
            consumptionKWh = newValue.converted(to: .kilowattHours).value
        }
    }
    
    var description: String {
        if associatedChargingLocation != nil {
            return "\(name) (\(associatedChargingLocation!.name))"
        } else {
            return "\(name)"
        }
    }
    
    var numberOfDays: Int {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: validFrom)
        let endDate = calendar.startOfDay(for: validUntil)
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        validFrom: Date,
        validUntil: Date,
        consumption: Measurement<UnitEnergy>,
        associatedChargingLocation: ChargingLocation? = nil
    ) {
        self.id = id
        self.name = name
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.consumptionKWh = consumption.converted(to: .kilowattHours).value
        self.associatedChargingLocation = associatedChargingLocation
    }
    
    func totalCost(isGross: Bool = true) -> Double {
        return priceElements.reduce(0.0) {
            switch $1.type {
            case .daily:
                return $0 + ($1.grossAmount * Double(numberOfDays))
            case .once:
                return $0 + $1.grossAmount
            case .byConsumption(let energyUnitSymbol):
                guard let energyUnit = UserSettings.shared.energyUnit(for: energyUnitSymbol) else {
                    fatalError("Unknown energy unit symbol: \(energyUnitSymbol)")
                }
                let convertedConsumption = consumption.converted(to: energyUnit).value
                return $0 + ($1.grossAmount * convertedConsumption)
            }
        }
    }
    
    /// Calculates the total cost per month for the duration of the home consumption.
    /// - Parameter isGross: Indicates whether to calculate gross or net costs. Default is true (gross).
    /// - Returns: A dictionary where keys are month identifiers in "yyyy-MM" format and values are the corresponding costs for that month.
    func totalCostPerMonth(isGross: Bool = true) -> [String: Double] {
        let calendar = Calendar.current
        let totalCost = totalCost(isGross: isGross)
        
        // Determine the number of days for each of the covered months, calculate each month's cost portion, and store them in a dictionary
        var costPerMonth: [String: Double] = [:]
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
            let daysInThisMonth = (components.day ?? 0) + 1
            
            // Determine the cost portion in this month
            costPerMonth[monthKey] = totalCost / Double(numberOfDays) * Double(daysInThisMonth)
            // Move to the next month
            currentDate = endOfMonth
        }
        
        // Normalize the costs to ensure they sum up to the total cost (to avoid rounding issues)
        let sumOfCosts = costPerMonth.values.reduce(0, +)
        if sumOfCosts != totalCost {
            let difference = totalCost - sumOfCosts
            if let firstKey = costPerMonth.keys.first {
                costPerMonth[firstKey]! += difference
            }
        }
        
        return costPerMonth
    }
}
