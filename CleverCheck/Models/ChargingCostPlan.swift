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
    enum PlanType: Codable, CustomStringConvertible {
        static var descriptionIndividual: String { NSLocalizedString("Individual", comment: "") }
        static var descriptionFlatrate: String { NSLocalizedString("Flatrate", comment: "") }
        static var descriptionHomeConsumption: String { NSLocalizedString("Home Consumption", comment: "") }
        static var descriptionRefunded: String { NSLocalizedString("Refunded", comment: "") }
        
        case individual(defaultKWhPrice: Cost?)
        case flatrate(monthlyRate: Cost)
        case homeConsumption(atLocationWithId: UUID)
        case refunded(atLocationWithId: UUID, byFlatrateWithID: UUID)
        
        var description: String {
            switch self {
            case .individual: return PlanType.descriptionIndividual
            case .flatrate: return PlanType.descriptionFlatrate
            case .homeConsumption: return PlanType.descriptionHomeConsumption
            case .refunded: return PlanType.descriptionRefunded
            }
        }
    }
    
    public var id: UUID
    var car: Car
    var charger: Charger
    var planType: PlanType
    var isArchived: Bool = false
    
    var description: String {
        "\(planType.description): \(car.description) / (\(charger.name))"
    }
    
    init(id: UUID = UUID(), car: Car, charger: Charger, planType: PlanType) {
        self.id = id
        self.car = car
        self.charger = charger
        self.planType = planType
    }
}
