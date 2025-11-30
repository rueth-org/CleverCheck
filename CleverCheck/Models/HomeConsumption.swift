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
    enum PriceElementType: String, Codable {
        case daily, oneTime = "one time", byConsumption = "by consumption"
    }
    
    struct PriceElement: Identifiable, Equatable, Codable {
        var id = UUID()
        var label: String
        var amount: Cost
        var type: PriceElementType
        
        static func == (lhs: HomeConsumption.PriceElement, rhs: HomeConsumption.PriceElement) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    var id = UUID()
    var name: String
    var validFrom: Date
    var validUntil: Date
    var consumptionKWh: Double
    private var priceElements: [PriceElement] = []
    
    @Transient var consumption: Measurement<UnitEnergy> {
        get {
            return Measurement<UnitEnergy>(value: consumptionKWh, unit: .kilowattHours)
        }
        set {
            consumptionKWh = newValue.converted(to: .kilowattHours).value
        }
    }
    
    init(name: String, validFrom: Date, validUntil: Date, consumption: Measurement<UnitEnergy>) {
        self.name = name
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.consumptionKWh = consumption.converted(to: .kilowattHours).value
    }
    
    func getPriceElements() -> [PriceElement] {
        return priceElements
    }
    
    /// Adds a new price element.
    /// - Parameters:
    ///   - label: The label of the price element, which must be unique.
    ///   - amount: The amount. A positive value is considered a cost, a negative value a deduction or refund.
    ///   - type: The type of the price element: If "daily", the amount is multiplied with the amount of days, if "one time", it is considered once, if "by consumption", it's multiplied with the consumption.
    /// - Returns: False if the label is not unique, true otherwise.
    func addPriceElement(label: String, amount: Cost, type: PriceElementType) -> Bool {
        if priceElements.contains(where: { $0.label == label }) {
            return false // Label must be unique
        }
        
        priceElements.append(.init(label: label, amount: amount, type: type))
        return true
    }
    
    func removePriceElement(_ priceElement: PriceElement) -> Bool {
        guard let index = priceElements.firstIndex(of: priceElement) else {
            return false
        }
        
        priceElements.remove(at: index)
        return true
    }
}
