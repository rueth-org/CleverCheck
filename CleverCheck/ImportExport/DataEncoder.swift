//
//  DataEncoder.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 29/12/2025.
//

import Foundation
import SwiftData

/// Utility to export all app models into a JSON backup.
///
/// Usage:
/// - Call `try DataEncoder.export(context: modelContext)` to get JSON data.
/// - Or `try DataEncoder.exportToFile(url: fileURL, context: modelContext)` to write to disk.
struct DataEncoder {
    static let currentDataModelVersion: String = "1"
    
    // MARK: - Backup DTOs

    struct Backup: Codable {
        var createdAt: Date = Date()
        var dataModelVersion: String = DataEncoder.currentDataModelVersion
        var cars: [CarDTO]
        var chargers: [ChargerDTO]
        var locations: [LocationDTO]
        var chargingCostPlans: [ChargingCostPlanDTO]
        var chargingSessions: [ChargingSessionDTO]
        var chargingSessionTemplates: [ChargingSessionTemplateDTO]
        var homeConsumptions: [HomeConsumptionDTO]
        var priceElements: [PriceElementDTO]
        var userSettings: UserSettingsDTO?
    }

    struct CarDTO: Codable {
        var id: UUID
        var make: String
        var model: String
        var defaultSOC: Double
        var netBatteryCapacityKWh: Double?
        var maxChargingPowerKW: Double?
        var averageReferenceFuelConsumption: FuelConsumption?
        var isArchived: Bool
        var chargingCostPlanIds: [UUID]
    }

    struct ChargerDTO: Codable {
        var id: UUID
        var name: String
        var locationId: UUID?
        var maxPowerKW: Double?
        var isArchived: Bool
        var chargingCostPlanIds: [UUID]
    }

    struct LocationDTO: Codable {
        var id: UUID
        var name: String
        var powerPriceServiceName: String?
        var powerPriceRegion: String?
        var isArchived: Bool
        var associatedHomeConsumptionIds: [UUID]
        var chargerIds: [UUID]
    }

    struct ChargingCostPlanDTO: Codable {
        enum PlanTypeDTO: Codable {
            case individual, flatrate, homeConsumption, homeDiscounted, refunded
        }

        var id: UUID
        var carId: UUID?
        var chargerId: UUID?
        var planType: PlanTypeDTO
        var defaultKWhPrice: Cost?
        var energyUnitSymbol: String
        var monthlyRate: Cost?
        var includedInOtherPlan: UUID?
        var displayColorString: String?
        var isArchived: Bool
        var chargingSessionIds: [UUID]
        var childCostPlanIds: [UUID]
    }

    struct ChargingSessionDTO: Codable {
        enum CostCalculationMethodDTO: String, Codable {
            case absolute, specific, both, none
        }

        var id: UUID
        var startTime: Date?
        var endTime: Date
        var chargedEnergyKWh: Double
        var chargingCostPlanId: UUID?
        var chargingCost: Cost?
        var specificChargingCost: Cost?
        var costCalculationMethod: CostCalculationMethodDTO
        var estimatedRealCost: Cost?
        var relatedHomeConsumptionId: UUID?
        var relatedRefundingHomeConsumptionId: UUID?
        var mileageKilometer: Double?
        var initialSOC: Double?
        var finalSOC: Double?
        var comment: String?
        var templateId: UUID?
    }
    
    struct ChargingSessionTemplateDTO: Codable {
        var id: UUID
        var name: String
        var chargingSessionId: UUID?
    }

    struct HomeConsumptionDTO: Codable {
        enum ConsumptionTypeDTO: Codable {
            case total, home, homeDiscount, homeRefunded, charging, chargingDiscount, chargingRefunded, refundingOtherPlan
        }
        
        var id: UUID
        var name: String
        var validFrom: Date
        var validUntil: Date
        var consumptionKWh: Double
        var consumptionType: ConsumptionTypeDTO
        var associatedLocationId: UUID?
        var defaultToEnteredConsumption: Bool
        var comment: String
        var priceElementIds: [UUID]
        var chargingSessionIds: [UUID]
        var refundedChargingSessionIds: [UUID]
    }

    struct PriceElementDTO: Codable {
        enum PriceElementTypeDTO: Codable {
            case daily
            case once
            case byConsumption(energyUnitSymbol: String)

            private enum CodingKeys: String, CodingKey { case type, energyUnitSymbol }
            private enum TypeIdentifier: String, Codable { case daily, once, byConsumption }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(TypeIdentifier.self, forKey: .type)
                switch type {
                case .daily: self = .daily
                case .once: self = .once
                case .byConsumption: let symbol = try container.decode(String.self, forKey: .energyUnitSymbol); self = .byConsumption(energyUnitSymbol: symbol)
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .daily:
                    try container.encode(TypeIdentifier.daily, forKey: .type)
                case .once:
                    try container.encode(TypeIdentifier.once, forKey: .type)
                case .byConsumption(let energyUnitSymbol):
                    try container.encode(TypeIdentifier.byConsumption, forKey: .type)
                    try container.encode(energyUnitSymbol, forKey: .energyUnitSymbol)
                }
            }
        }

        var id: UUID
        var homeConsumptionId: UUID?
        var label: String
        var amount: Cost
        var isGross: Bool
        var type: PriceElementTypeDTO
        var vatRate: Double
        var excludeFromSimulation: Bool
    }

    struct UserSettingsDTO: Codable {
        var measurementSystem: String
        var currencyIdentifier: String
        var energyUnitSymbol: String
        var powerUnitSymbol: String
        var vatRate: Double
        var displayGrossPrices: Bool
    }

    // MARK: - Export API

    /// Exports all models from the given `ModelContext` into JSON `Data`.
    /// - Parameter context: The SwiftData `ModelContext` to read objects from.
    /// - Returns: JSON data representing the backup.
    static func export(context: ModelContext) throws -> Data {
        // Fetch all models
        let cars: [Car] = try context.fetch(FetchDescriptor<Car>())
        let chargers: [Charger] = try context.fetch(FetchDescriptor<Charger>())
        let locations: [Location] = try context.fetch(FetchDescriptor<Location>())
        let chargingCostPlans: [ChargingCostPlan] = try context.fetch(FetchDescriptor<ChargingCostPlan>())
        let chargingSessions: [ChargingSession] = try context.fetch(FetchDescriptor<ChargingSession>())
        let chargingSessionTemplates: [ChargingSessionTemplate] = try context.fetch(FetchDescriptor<ChargingSessionTemplate>())
        let homeConsumptions: [HomeConsumption] = try context.fetch(FetchDescriptor<HomeConsumption>())
        let priceElements: [PriceElement] = try context.fetch(FetchDescriptor<PriceElement>())

        // Map to DTOs
        let carDTOs = cars.map { car in
            CarDTO(
                id: car.id,
                make: car.make,
                model: car.model,
                defaultSOC: car.defaultSOC,
                netBatteryCapacityKWh: car.netBatteryCapacityKWh,
                maxChargingPowerKW: car.maxChargingPowerkW,
                averageReferenceFuelConsumption: car.averageReferenceFuelConsumption,
                isArchived: car.isArchived,
                chargingCostPlanIds: car.chargingCostPlans?.map { $0.id } ?? []
            )
        }

        let chargerDTOs = chargers.map { charger in
            ChargerDTO(
                id: charger.id,
                name: charger.name,
                locationId: charger.location?.id,
                maxPowerKW: charger.maxPowerKW,
                isArchived: charger.isArchived,
                chargingCostPlanIds: charger.chargingCostPlans?.map { $0.id } ?? []
            )
        }

        let locationDTOs = locations.map { location in
            LocationDTO(
                id: location.id,
                name: location.name,
                powerPriceServiceName: location.powerPriceServiceName,
                powerPriceRegion: location.powerPriceRegion,
                isArchived: location.isArchived,
                associatedHomeConsumptionIds: location.associatedHomeConsumptions?.map { $0.id } ?? [],
                chargerIds: location.chargers?.map { $0.id } ?? []
            )
        }

        let chargingCostPlanDTOs = chargingCostPlans.map { plan in
            // Map plan type
            let planTypeDTO: ChargingCostPlanDTO.PlanTypeDTO
            switch plan.planType {
            case .individual: planTypeDTO = .individual
            case .flatrate: planTypeDTO = .flatrate
            case .homeConsumption: planTypeDTO = .homeConsumption
            case .homeDiscounted: planTypeDTO = .homeDiscounted
            case .refunded: planTypeDTO = .refunded
            }
            
            let defaultKWhPrice: Cost? = {
                if let defaultEnergyPrice = plan.defaultEnergyPrice {
                    if let convertedPrice = UserSettings.shared.convertEnergyPrice(amount: defaultEnergyPrice.amount, from: plan.energyUnitSymbol, to: "kWh") {
                        return Cost(amount: convertedPrice, currency: defaultEnergyPrice.currency)
                    }
                }
                
                return nil
            }()

            return ChargingCostPlanDTO(
                id: plan.id,
                carId: plan.car?.id,
                chargerId: plan.charger?.id,
                planType: planTypeDTO,
                defaultKWhPrice: defaultKWhPrice,
                energyUnitSymbol: plan.energyUnitSymbol,
                monthlyRate: plan.monthlyRate,
                includedInOtherPlan: plan.includedInOtherPlan?.id,
                displayColorString: plan.displayColorString,
                isArchived: plan.isArchived,
                chargingSessionIds: plan.chargingSessions?.map { $0.id } ?? [],
                childCostPlanIds: plan.childCostPlans?.map { $0.id } ?? []
            )
        }

        let chargingSessionDTOs = chargingSessions.map { session in
            // Map costCalculationMethod
            let calcMethod: ChargingSessionDTO.CostCalculationMethodDTO
            switch session.costCalculationMethod {
            case .absolute: calcMethod = .absolute
            case .specific: calcMethod = .specific
            case .both: calcMethod = .both
            case .none: calcMethod = .none
            }

            return ChargingSessionDTO(
                id: session.id,
                startTime: session.startTime,
                endTime: session.endTime,
                chargedEnergyKWh: session.chargedEnergyKWh,
                chargingCostPlanId: session.chargingCostPlan?.id,
                chargingCost: session.chargingCost,
                specificChargingCost: session.specificChargingCost,
                costCalculationMethod: calcMethod,
                estimatedRealCost: session.estimatedRealCost,
                relatedHomeConsumptionId: session.relatedHomeConsumption?.id,
                relatedRefundingHomeConsumptionId: session.relatedRefundingHomeConsumption?.id,
                mileageKilometer: session.mileageKilometer,
                initialSOC: session.initialSOC,
                finalSOC: session.finalSOC,
                comment: session.comment,
                templateId: session.template?.id
            )
        }
        
        let chargingSessionsTemplateDTOs = chargingSessionTemplates.map { session in
            ChargingSessionTemplateDTO(
                id: session.id,
                name: session.name,
                chargingSessionId: session.chargingSession?.id
            )
        }

        let homeConsumptionDTOs = homeConsumptions.map { home in
            // Map consumption type
            let consumptionTypeDTO: HomeConsumptionDTO.ConsumptionTypeDTO
            switch home.consumptionType {
            case .total: consumptionTypeDTO = .total
            case .home: consumptionTypeDTO = .home
            case .homeDiscount: consumptionTypeDTO = .homeDiscount
            case .homeRefunded: consumptionTypeDTO = .homeRefunded
            case .charging: consumptionTypeDTO = .charging
            case .chargingDiscount: consumptionTypeDTO = .chargingDiscount
            case .chargingRefunded: consumptionTypeDTO = .chargingRefunded
            case .refundingOtherPlan: consumptionTypeDTO = .refundingOtherPlan
            }
            
            return HomeConsumptionDTO(
                id: home.id,
                name: home.name,
                validFrom: home.validFrom,
                validUntil: home.validUntil,
                consumptionKWh: home.consumptionKWh,
                consumptionType: consumptionTypeDTO,
                associatedLocationId: home.associatedLocation?.id,
                defaultToEnteredConsumption: home.defaultToEnteredConsumption,
                comment: home.comment,
                priceElementIds: home.priceElements?.map { $0.id } ?? [],
                chargingSessionIds: home.chargingSessions?.map { $0.id } ?? [],
                refundedChargingSessionIds: home.refundedChargingSessions?.map { $0.id } ?? []
            )
        }

        let priceElementDTOs = priceElements.map { p in
            // Map PriceElementType
            let typeDTO: PriceElementDTO.PriceElementTypeDTO
            switch p.type {
            case .daily:
                typeDTO = .daily
            case .once:
                typeDTO = .once
            case .byConsumption(let energyUnitSymbol):
                typeDTO = .byConsumption(energyUnitSymbol: energyUnitSymbol)
            }

            return PriceElementDTO(
                id: p.id,
                homeConsumptionId: p.homeConsumption?.id,
                label: p.label,
                amount: p.amount,
                isGross: p.isGross,
                type: typeDTO,
                vatRate: p.vatRate,
                excludeFromSimulation: p.excludeFromSimulation
            )
        }

        // User settings snapshot
        let settingsDTO = UserSettingsDTO(
            measurementSystem: UserSettings.shared.measurementSystemIdentifier,
            currencyIdentifier: UserSettings.shared.currencyIdentifier,
            energyUnitSymbol: UserSettings.shared.energyUnitSymbol,
            powerUnitSymbol: UserSettings.shared.powerUnitSymbol,
            vatRate: UserSettings.shared.vatRate,
            displayGrossPrices: UserSettings.shared.displayGrossPrices
        )

        let backup = Backup(
            createdAt: Date(),
            cars: carDTOs,
            chargers: chargerDTOs,
            locations: locationDTOs,
            chargingCostPlans: chargingCostPlanDTOs,
            chargingSessions: chargingSessionDTOs,
            chargingSessionTemplates: chargingSessionsTemplateDTOs,
            homeConsumptions: homeConsumptionDTOs,
            priceElements: priceElementDTOs,
            userSettings: settingsDTO
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    /// Exports and writes the JSON backup to the given file URL.
    /// - Parameters:
    ///   - url: Destination file URL (will be overwritten if exists).
    ///   - context: The SwiftData `ModelContext` to read objects from.
    /// - Returns: The file URL written.
    static func exportToFile(url: URL, context: ModelContext) throws -> URL {
        let data = try export(context: context)
        try data.write(to: url, options: .atomic)
        return url
    }
}
