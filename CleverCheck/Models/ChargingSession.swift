//
//  ChargingSession.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class ChargingSession: Comparable {
    enum CostCalculationMethod: Codable {
        case absolute
        case specific
        case both
        case none
        
        func description() -> LocalizedStringKey {
            switch self {
            case .absolute: return "Absolut cost"
            case .specific: return "Specific cost"
            case .both: return "Absolut and specific cost"
            case .none: return "No cost"
            }
        }
    }
    
    var id: UUID = UUID()
    var startTime: Date?
    var endTime: Date = Date.now
    var chargedEnergyKWh: Double = 0.0
    var chargingCostPlan: ChargingCostPlan?
    var chargingCost: Cost?
    var specificChargingCost: Cost?
    var costCalculationMethod: CostCalculationMethod = CostCalculationMethod.none
    var estimatedRealCost: Cost?
    var relatedHomeConsumption: HomeConsumption?
    var relatedRefundingHomeConsumption: HomeConsumption?
    var mileageKilometer: Double?
    var initialSOC: Double?
    var finalSOC: Double?
    var comment: String?
    var template: ChargingSessionTemplate?
    
    @Transient var chargedEnergy: Measurement<UnitEnergy> {
        get {
            return Measurement<UnitEnergy>(value: chargedEnergyKWh, unit: .kilowattHours)
        }
        set {
            chargedEnergyKWh = newValue.converted(to: .kilowattHours).value
        }
    }
    
    @Transient var mileage: Measurement<UnitLength>? {
        get {
            if let mileageKilometer {
                return Measurement<UnitLength>(value: mileageKilometer, unit: .kilometers)
            } else {
                return nil
            }
        }
        set {
            mileageKilometer = newValue?.converted(to: .kilometers).value
        }
    }
    
    var description: String {
        "\(UserSettings.shared.shortDateFormatter.string(from: endTime)) - \(chargingCostPlan?.descriptionLong ?? "Unknown plan"): \(chargedEnergyFormatted)"
    }
    
    var chargedEnergyFormatted: String {
        chargedEnergy.converted(to: UserSettings.shared.energyUnit).formatted(.measurement(width: .narrow, usage: .asProvided))
    }
    
    var totalChargingCost: Cost {
        switch costCalculationMethod {
        case .none: return .init(amount: 0.0)
        case .absolute:
            if let chargingCost {
                return chargingCost.converted(to: UserSettings.shared.currencyIdentifier) ?? chargingCost
            } else {
                return .init(amount: 0.0)
            }
        case .specific:
            var totalCost = 0.0
            if let specificChargingCost {
                totalCost += (specificChargingCost.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? specificChargingCost.amount) * chargedEnergy(in: UserSettings.shared.energyUnit).value
            }
            let convertedTotalCost = UserSettings.shared.convertEnergyPrice(amount: totalCost, from: .kilowattHours, to: UserSettings.shared.energyUnit)
            return .init(amount: convertedTotalCost)
        case .both:
            var totalCost = 0.0
            if let specificChargingCost {
                totalCost += (specificChargingCost.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? specificChargingCost.amount) * chargedEnergy(in: UserSettings.shared.energyUnit).value
            }
            if let chargingCost {
                totalCost += chargingCost.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? chargingCost.amount
            }
            let convertedTotalCost = UserSettings.shared.convertEnergyPrice(amount: totalCost, from: .kilowattHours, to: UserSettings.shared.energyUnit)
            return .init(amount: convertedTotalCost)
        }
    }
    
    var isTemplate: Bool {
        self.template != nil
    }
    
    init(
        startTime: Date? = nil,
        endTime: Date,
        chargedEnergy: Measurement<UnitEnergy>,
        chargingCostPlan: ChargingCostPlan,
        chargingCost: Cost? = nil,
        specificChargingCost: Cost? = nil,
        costCalculationMethod: CostCalculationMethod = .none,
        mileage: Measurement<UnitLength>? = nil,
        initialSOC: Double? = nil,
        finalSOC: Double? = nil,
        useDefaultFinalSOC: Bool = false,
        comment: String? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.chargedEnergyKWh = chargedEnergy.converted(to: .kilowattHours).value
        self.chargingCostPlan = chargingCostPlan
        self.chargingCost = chargingCost
        self.specificChargingCost = specificChargingCost
        self.costCalculationMethod = costCalculationMethod
        self.mileageKilometer = mileage?.converted(to: .kilometers).value
        self.initialSOC = initialSOC
        if useDefaultFinalSOC, chargingCostPlan.car != nil {
            self.finalSOC = chargingCostPlan.car!.defaultSOC
        } else {
            self.finalSOC = finalSOC
        }
        self.comment = comment
    }
    
    func chargedEnergy(in unitEnergy: UnitEnergy) -> Measurement<UnitEnergy> {
        chargedEnergy.converted(to: unitEnergy)
    }
    
    func estimateRealCost(modelContext: ModelContext) async throws -> (cost: Cost, refundingHomeConsumption: HomeConsumption?) {
        // We need a location
        guard let location = chargingCostPlan?.charger?.location else {
            throw EnergyDataService.EnergyDataError.noLocation
        }
        
        // We need a related home consumption
        guard var relatedHomeConsumption = relatedHomeConsumption else {
            throw EnergyDataService.EnergyDataError.noRelatedHomeConsumption
        }
        
        var returnRefundingHomeConsumption = false
        if relatedHomeConsumption.consumptionType == .refundingOtherPlan {
            // If the type is refundingOtherPlan, we need to find the home consumption of related to this other plan
            returnRefundingHomeConsumption = true
            if let relatedRefundingHomeConsumption {
                relatedHomeConsumption = relatedRefundingHomeConsumption
            } else {
                if let candidates = possibleHomeConsumptions(modelContext: modelContext), candidates.count > 0 {
                    debugPrint("Found \(candidates.count) candidate home consumptions for refunding plan")
                    debugPrint(candidates.map { $0.description }.joined(separator: "\n"))
                    if candidates.count == 1 {
                        relatedHomeConsumption = candidates[0]
                    } else {
                        // Filter further by home consumption type .total or .home
                        let filteredCandidates = candidates.filter { consumption in
                            consumption.consumptionType == .total || consumption.consumptionType == .home
                        }
                        if filteredCandidates.count == 1 {
                            relatedHomeConsumption = filteredCandidates[0]
                        } else {
                            // There are too many candidates, we can't determine which one is the right one, so we throw an error
                            throw EnergyDataService.EnergyDataError.multipleRelatedHomeConsumptions(filteredCandidates.map { $0.description })
                        }
                    }
                } else {
                    throw EnergyDataService.EnergyDataError.noRelatedRefundingHomeConsumption
                }
            }
        }
        
        // Check if related home consumption is of type .total or .home, everything else does not makes sense
        if relatedHomeConsumption.consumptionType != .total && relatedHomeConsumption.consumptionType != .home {
            throw EnergyDataService.EnergyDataError.invalidRelatedHomeConsumptionType
        }
        
        // We need either a start time, or the charger's maxPowerKW, to be able to estimate the real cost
        var startTime: Date? = self.startTime
        if startTime == nil, let charger = chargingCostPlan?.charger {
            if let maxPowerKW = charger.maxPowerKW {
                // We can estimate the duration of the charging session by dividing the charged energy by the max power of the charger
                let estimatedDurationHours = chargedEnergyKWh / maxPowerKW
                startTime = endTime.addingTimeInterval(-estimatedDurationHours * 3600)
            } else {
                // We don't have a start time, and we can't estimate it, so we can't estimate the real cost
                throw EnergyDataService.EnergyDataError.cannotDetermineDuration
            }
        }
        
        guard let startTime = startTime else {
            throw EnergyDataService.EnergyDataError.cannotDetermineDuration
        }
        
        // Calculate the consumed energy per minute
        let durationMinutes: Double = endTime.timeIntervalSince(startTime) / 60
        if durationMinutes.isZero {
            throw EnergyDataService.EnergyDataError.cannotDetermineDuration
        }
        let energyPerMinute: Double = chargedEnergyKWh / durationMinutes
        
        // Use singleton energy data service and retrieve the power price for the time of the charging session
        let energyDataService = EnergyDataService.shared
        let energyPrices = try await energyDataService.dayAheadPrices(for: location, from: startTime, to: endTime)
        
        // Calculate the real cost by multiplying the energy price for each minute with the energy consumed in that minute, and summing up the total cost
        var totalCost: Cost = .init(amount: 0.0)
        var currentTime = startTime
        
        // Caching variables
        var pricePerKWh: Cost = .init(amount: 0.0)
        var cost: Cost = .init(amount: 0.0)
        
        while currentTime < endTime {
            // Find the energy price for the current time
            if let price = energyPrices.first(where: { $0.timeUTC <= currentTime && currentTime < $0.timeUTC.addingTimeInterval(Double($0.resolutionMinutes) * 60) }) {
                // Add the cost for this minute to the total cost
                if pricePerKWh != price.pricePerKWh {
                    // Only recalculate cost if price has changed, otherwise we can reuse the previous cost calculation, which is more efficient
                    pricePerKWh = price.pricePerKWh
                    cost = relatedHomeConsumption.simulateCost(of: energyPerMinute, with: price.pricePerKWh, durationInMinutes: 1)
                }
                    
                totalCost += cost
            } else {
                throw EnergyDataService.EnergyDataError.notFound("No energy price found for time \(currentTime)")
            }
            currentTime = currentTime.addingTimeInterval(60) // Move to the next minute
        }
        
        return (cost: totalCost, refundingHomeConsumption: returnRefundingHomeConsumption ? relatedHomeConsumption : nil)
    }

    
    func possibleHomeConsumptions(modelContext: ModelContext, ignoreDate: Bool = false) -> [HomeConsumption]? {
        if let homeConsumptions = try? modelContext.fetch(FetchDescriptor<HomeConsumption>()) {
            if homeConsumptions.isEmpty {
                return nil
            } else {
                // Get all home consumptions related to the same location as the charging session's plan, if available
                var candidates: [HomeConsumption] = homeConsumptions
                
                if let chargingCostPlan, let location = chargingCostPlan.charger?.location {
                    candidates = candidates.filter { consumption in
                        consumption.associatedLocation != nil && consumption.associatedLocation!.id == location.id
                    }
                }
                
                // Apply time filter if needed
                if !ignoreDate {
                    candidates = candidates.filter { consumption in
                        consumption.validFrom <= endTime && endTime <= consumption.validUntil
                    }
                }
                
                return candidates.isEmpty ? nil : candidates.sorted(by: { $0.descriptionWithDate < $1.descriptionWithDate })
            }
        } else {
            return nil
        }
    }
    
    func possibleHomeConsumptionsRefunded(modelContext: ModelContext, ignorePlan: Bool, ignoreDate: Bool) -> [HomeConsumption]? {
        if let homeConsumptions = try? modelContext.fetch(FetchDescriptor<HomeConsumption>()) {
            if homeConsumptions.isEmpty {
                return nil
            } else {
                var candidates: [HomeConsumption] = homeConsumptions
                
                // First try to identify matching plans
                if let chargingCostPlan, !ignorePlan {
                    // Find the refunding plan, which should be available, as we only deal with refunded plan type
                    if let refundingPlan = chargingCostPlan.includedInOtherPlan {
                        // Now locate the charger
                        if let location = refundingPlan.charger?.location {
                            // This location should match the location of home consumption
                            candidates = candidates.filter { consumption in
                                consumption.associatedLocation != nil && consumption.associatedLocation!.id == location.id
                            }
                        }
                    }
                }
                
                // Apply time filter if needed
                if !ignoreDate {
                    candidates = candidates.filter { consumption in
                        consumption.validFrom <= endTime && endTime <= consumption.validUntil
                    }
                }
                
                debugPrint("Found \(candidates.count) candidate home consumptions for refunding plan: \(candidates.map { $0.descriptionWithDate }.joined(separator: ", "))")
                
                return candidates.isEmpty ? nil : candidates.sorted(by: { $0.descriptionWithDate < $1.descriptionWithDate })
            }
        } else {
            return nil
        }
    }
    
    static func < (lhs: ChargingSession, rhs: ChargingSession) -> Bool {
        lhs.endTime < rhs.endTime
    }
}

