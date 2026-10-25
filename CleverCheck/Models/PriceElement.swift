//
//  PriceElement.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 02/12/2025.
//

import Foundation
import SwiftData

@Model
final class PriceElement: Identifiable, Equatable {
    enum PriceElementType: Codable, Hashable {
        static var descriptionDaily: String { NSLocalizedString("Daily", comment: "") }
        static var descriptionOnce: String { NSLocalizedString("Once", comment: "") }
        static var descriptionByConsumption: String { NSLocalizedString("By consumption", comment: "") }
        
        case daily
        case once
        case byConsumption(energyUnitSymbol: String)
        
        var unitExtension: String {
            switch self {
            case .daily:
                return NSLocalizedString("/day", comment: "")
            case .once:
                return ""
            case .byConsumption(let energyUnitSymbol):
                return "/\(energyUnitSymbol)"
            }
        }
        
        var description: String {
            switch self {
            case .daily: return PriceElementType.descriptionDaily
            case .once: return PriceElementType.descriptionOnce
            case .byConsumption: return PriceElementType.descriptionByConsumption
            }
        }
        
        static var allCases: [PriceElementType] {
            return [.daily, .once, .byConsumption(energyUnitSymbol: UserSettings.shared.energyUnit.symbol)]
        }
    }
    
    var id: UUID = UUID()
    var homeConsumption: HomeConsumption?
    var label: String = ""
    var amount: Cost = Cost(amount: 0.0)
    var isGross: Bool = true
    var seasonalPrice: SeasonalPrice?
    var type: PriceElementType = PriceElementType.byConsumption(energyUnitSymbol: UserSettings.shared.energyUnitSymbol)
    var vatRate: Double = 0.25
    var excludeFromSimulation: Bool = false
    
    var isSeasonal: Bool {
        seasonalPrice != nil
    }
    
    /// Returns the amount converted to the user's selected currency. If conversion fails, returns the original amount.
    var converted: Cost {
        amount.converted(to: UserSettings.shared.currencyIdentifier) ?? amount
    }
    
    var unitDescription: String {
        "\(converted.currency)\(type.unitExtension)"
    }
    
    var amountDescription: String {
        return "\(UserSettings.shared.format(self.converted.amount, withSignificantDigits: 4)) \(unitDescription)"
    }
    
    var netGrossDescription: String {
        isGross ? "Gross" : "Net"
    }
    
    init(label: String, amount: Cost, inclVAT: Bool, type: PriceElementType, vatRate: Double? = nil, excludeFromSimulation: Bool = false) {
        self.label = label
        self.amount = amount
        self.type = type
        self.vatRate = vatRate ?? UserSettings.shared.vatRate
        self.isGross = inclVAT
        self.excludeFromSimulation = excludeFromSimulation
    }
    
    /// Returns the net amount based on the converted gross amount and VAT rate. If the original amount is already net, it simply returns the converted amount.
    private func exclVAT(_ cost: Cost) -> Cost {
        if isGross {
            return Cost(amount: cost.amount / (1 + vatRate), currency: cost.currency)
        } else {
            return cost
        }
    }
    
    /// Returns the gross amount based on the converted net amount and VAT rate. If the original amount is already gross, it simply returns the converted amount.
    private func inclVAT(_ cost: Cost) -> Cost {
        if isGross {
            return cost
        } else {
            return Cost(amount: cost.amount * (1 + vatRate), currency: cost.currency)
        }
    }
    
    /// Returns the converted cost in the user's selected currency, either gross or net based on the isGross parameter.
    /// - Parameter isGross: If true, returns the gross amount; if false, returns the net amount.
    /// - Returns: The converted cost. If conversion fails, returns the original cost.
    func getConvertedCost(includingVAT: Bool) -> Cost {
        if includingVAT {
            return inclVAT(converted)
        } else {
            return exclVAT(converted)
        }
    }
    
    /// Calculates the average seasonal cost from the given start to the given end time.
    /// - Parameters:
    ///   - startTime: The start time.
    ///   - endTime: The end time.
    ///   - includingVAT: If true, VAT is included.
    /// - Returns: The average seasonal cost.
    func getConvertedSeasonalCost(startTime: Date, endTime: Date, includingVAT: Bool) -> Cost? {
        guard let seasonalPrice else { return nil }
        let durationInMinutes = endTime.timeIntervalSince(startTime) / 60.0
        guard durationInMinutes > 0.0 else { return nil }
        let calendar = Calendar.current
        
        // Get the hour and minute of start time as integer
        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        
        // Get the hour and minute of end time as integer
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)
        
        // Iterate from start hour and start minute to end hour and end minute and sum up seasonal price for each minute
        var hour = startHour
        var minute = startMinute
        var summedPrice = 0.0
        while hour < endHour || (hour == endHour && minute < endMinute) {
            let price = seasonalPrice.getConvertedPrice(hour: hour, minute: minute).amount
            summedPrice += price
            minute += 1
            if minute == 60 {
                hour += 1
                minute = 0
            }
        }
        
        // Calculate the average price
        let averagePrice = Cost(amount: summedPrice / durationInMinutes)
        
        if includingVAT {
            return inclVAT(averagePrice)
        } else {
            return exclVAT(averagePrice)
        }
    }
    
    static func == (lhs: PriceElement, rhs: PriceElement) -> Bool {
        lhs.id == rhs.id
    }
}
