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
        static var descriptionFlatrate: String { NSLocalizedString("Flatrate", comment: "") }
        static var descriptionRefunded: String { NSLocalizedString("Refunded", comment: "") }
        static var descriptionIndividual: String { NSLocalizedString("Individual", comment: "") }
        
        case flatrate(monthlyRate: Double)
        case refunded(atLocationWithId: UUID)
        case individual(defaultKWhPrice: Double?)
        
        var description: String {
            switch self {
            case .flatrate: return PlanType.descriptionFlatrate
            case .refunded: return PlanType.descriptionRefunded
            case .individual: return PlanType.descriptionIndividual
            }
        }
    }
    
    var car: Car
    var charger: Charger
    var planType: PlanType
    
    init(car: Car, charger: Charger, planType: PlanType) {
        self.car = car
        self.charger = charger
        self.planType = planType
    }
}
