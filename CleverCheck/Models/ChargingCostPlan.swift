//
//  ChargingCostPlan.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 28/11/2025.
//

import Foundation
import SwiftData

@Model
public final class ChargingCostPlan {
    enum PlanType: String, Codable, CustomStringConvertible {
        case individual = "Individual"
        case flatrate = "Flatrate"
        case homeConsumption = "Home Consumption"
        case refunded = "Refunded"
        
        var description: String {
            NSLocalizedString(self.rawValue, comment: "")
        }
    }
    
    public var id: UUID = UUID()
    var car: Car?
    var charger: Charger?
    var planType: PlanType = PlanType.individual
    var defaultEnergyPrice: Cost?
    var energyUnitSymbol: String = UserSettings.shared.energyUnitSymbol
    var monthlyRate: Cost?
    var relatedLocation: Location?
    var includedInOtherPlan: ChargingCostPlan?
    var isArchived: Bool = false
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingSession.chargingCostPlan)
    var chargingSessions: [ChargingSession]?
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingCostPlan.includedInOtherPlan)
    var childCostPlans: [ChargingCostPlan]?
    
    var descriptionShortNoCar: String {
        "\(charger?.description ?? "Unknown charger")"
    }
    
    var descriptionShort: String {
        "\(car?.description ?? "Unknown car") - \(descriptionShortNoCar)"
    }
    
    var descriptionLongNoCar: String {
        "\(descriptionShortNoCar) (\(planType.description))"
    }
    
    var descriptionLong: String {
        "\(descriptionShort) (\(planType.description))"
    }
    
    init(
        car: Car,
        charger: Charger,
        planType: PlanType,
        defaultEnergyPrice: Cost? = nil,
        monthlyRate: Cost? = nil,
        relatedLocation: Location? = nil,
        includedInOtherPlan: ChargingCostPlan? = nil
    ) {
        self.car = car
        self.charger = charger
        self.planType = planType
        self.defaultEnergyPrice = defaultEnergyPrice
        self.monthlyRate = monthlyRate
        self.relatedLocation = relatedLocation
        self.includedInOtherPlan = includedInOtherPlan
    }
}

