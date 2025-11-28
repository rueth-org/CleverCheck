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
        case flatrate(monthlyRate: Double)
        case refunded(atLocationWithId: UUID)
        case individual(defaultKWhPrice: Double?)
        
        var description: String {
            switch self {
            case .flatrate: return NSLocalizedString("Flatrate", comment: "")
            case .refunded: return NSLocalizedString("Refunded", comment: "")
            case .individual: return NSLocalizedString("Individual", comment: "")
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
