import Foundation
import SwiftData

public enum DataImportError: Error {
    case decodingError(Error)
    case persistenceError(Error)
}

public struct DataImportReport {
    public var cars: Int = 0
    public var chargers: Int = 0
    public var locations: Int = 0
    public var chargingCostPlans: Int = 0
    public var chargingSessions: Int = 0
    public var chargingSessionTemplates: Int = 0
    public var homeConsumptions: Int = 0
    public var priceElements: Int = 0
    public var userSettingsApplied: Bool = false
    public var errors: [String] = []
}

/// Imports a full backup JSON file produced by `DataEncoder`.
public struct DataImporter {
    /// Import from raw JSON Data (the shape produced by `DataEncoder.Backup`).
    /// - Parameters:
    ///   - data: JSON data produced by `DataEncoder.export`
    ///   - modelContext: the SwiftData `ModelContext` to insert objects into
    /// - Returns: an import report summarising the operation.
    public static func importFrom(data: Data, into modelContext: ModelContext) throws -> DataImportReport {
        var report = DataImportReport()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let backup = try decoder.decode(DataEncoder.Backup.self, from: data)

            // Dictionaries to map DTO ids to created model instances
            var carsById: [UUID: Car] = [:]
            var locationsById: [UUID: Location] = [:]
            var chargersById: [UUID: Charger] = [:]
            var plansById: [UUID: ChargingCostPlan] = [:]
            var homeConsumptionsById: [UUID: HomeConsumption] = [:]
            var priceElementsById: [UUID: PriceElement] = [:]
            var sessionsById: [UUID: ChargingSession] = [:]

            // Prefetch existing objects once to avoid repeated fetches and actor issues
            let existingCars: [Car] = (try? modelContext.fetch(FetchDescriptor<Car>())) ?? []
            let existingCarsById = Dictionary(uniqueKeysWithValues: existingCars.map { ($0.id, $0) })
            let existingCarIds = Set(existingCarsById.keys)

            let existingLocations: [Location] = (try? modelContext.fetch(FetchDescriptor<Location>())) ?? []
            let existingLocationsById = Dictionary(uniqueKeysWithValues: existingLocations.map { ($0.id, $0) })
            let existingLocationIds = Set(existingLocationsById.keys)

            let existingChargers: [Charger] = (try? modelContext.fetch(FetchDescriptor<Charger>())) ?? []
            let existingChargersById = Dictionary(uniqueKeysWithValues: existingChargers.map { ($0.id, $0) })
            let existingChargerIds = Set(existingChargersById.keys)

            let existingPlans: [ChargingCostPlan] = (try? modelContext.fetch(FetchDescriptor<ChargingCostPlan>())) ?? []
            let existingPlansById = Dictionary(uniqueKeysWithValues: existingPlans.map { ($0.id, $0) })
            let existingPlanIds = Set(existingPlansById.keys)

            let existingHomeConsumptions: [HomeConsumption] = (try? modelContext.fetch(FetchDescriptor<HomeConsumption>())) ?? []
            let existingHomeConsumptionsById = Dictionary(uniqueKeysWithValues: existingHomeConsumptions.map { ($0.id, $0) })
            let existingHomeConsumptionIds = Set(existingHomeConsumptionsById.keys)

            // Insert cars
            for dto in backup.cars {
                // Skip if existing car with same id
                if existingCarIds.contains(dto.id) {
                    continue
                }

                let car = Car(make: dto.make, model: dto.model, defaultSOC: dto.defaultSOC)
                car.id = dto.id
                car.netBatteryCapacityKWh = dto.netBatteryCapacityKWh
                car.maxChargingPowerkW = dto.maxChargingPowerKW
                car.isArchived = dto.isArchived
                modelContext.insert(car)
                carsById[dto.id] = car
                report.cars += 1
            }

            // Insert locations
            for dto in backup.locations {
                if existingLocationIds.contains(dto.id) {
                    continue
                }

                let location = Location(name: dto.name)
                location.id = dto.id
                location.isArchived = dto.isArchived
                modelContext.insert(location)
                locationsById[dto.id] = location
                report.locations += 1
            }

            // Insert chargers
            for dto in backup.chargers {
                if existingChargerIds.contains(dto.id) {
                    continue
                }

                let location = dto.locationId.flatMap { locationsById[$0] } ?? dto.locationId.flatMap { existingLocationsById[$0] }
                let charger = Charger(name: dto.name, location: location, maxPower: dto.maxPowerKW == nil ? nil : Measurement<UnitPower>(value: dto.maxPowerKW!, unit: .kilowatts))
                charger.id = dto.id
                charger.isArchived = dto.isArchived
                modelContext.insert(charger)
                chargersById[dto.id] = charger
                report.chargers += 1
            }

            // Insert charging cost plans
            for dto in backup.chargingCostPlans {
                if existingPlanIds.contains(dto.id) {
                    continue
                }

                // Map plan type
                let planType: ChargingCostPlan.PlanType
                switch dto.planType {
                case .individual: planType = .individual
                case .flatrate: planType = .flatrate
                case .homeConsumption: planType = .homeConsumption
                case .homeDiscounted: planType = .homeDiscounted
                case .refunded: planType = .refunded
                }

                let car = dto.carId.flatMap { carsById[$0] } ?? dto.carId.flatMap { existingCarsById[$0] }
                let charger = dto.chargerId.flatMap { chargersById[$0] } ?? dto.chargerId.flatMap { existingChargersById[$0] }

                // Ensure fallback Car/Charger placeholders are also inserted into the modelContext
                let planCar: Car
                if let existingCar = car {
                    planCar = existingCar
                } else {
                    planCar = Car(make: "", model: "")
                    modelContext.insert(planCar)
                }

                let planCharger: Charger
                if let existingCharger = charger {
                    planCharger = existingCharger
                } else {
                    planCharger = Charger(name: dto.id.uuidString)
                    modelContext.insert(planCharger)
                }

                let plan = ChargingCostPlan(
                    car: planCar,
                    charger: planCharger,
                    planType: planType,
                    defaultEnergyPrice: dto.defaultKWhPrice,
                    monthlyRate: dto.monthlyRate,
                    includedInOtherPlan: nil,
                    displayColor: dto.displayColorString.flatMap { DisplayColor(rawValue: $0) }
                )

                plan.id = dto.id
                plan.energyUnitSymbol = dto.energyUnitSymbol
                plan.isArchived = dto.isArchived
                modelContext.insert(plan)
                plansById[dto.id] = plan
                report.chargingCostPlans += 1
            }

            // After creating plans, wire includedInOtherPlan relationships
            for dto in backup.chargingCostPlans {
                if let includedId = dto.includedInOtherPlan, let plan = plansById[dto.id], let includedPlan = plansById[includedId] {
                    plan.includedInOtherPlan = includedPlan
                }
            }

            // Insert home consumptions
            for dto in backup.homeConsumptions {
                if existingHomeConsumptionIds.contains(dto.id) {
                    continue
                }

                let location = dto.associatedLocationId.flatMap { locationsById[$0] } ?? dto.associatedLocationId.flatMap { existingLocationsById[$0] }

                let consumption = Measurement<UnitEnergy>(value: dto.consumptionKWh, unit: .kilowattHours)
                
                // Map consumption type
                let consumptionType: HomeConsumption.ConsumptionType
                switch dto.consumptionType {
                case .total: consumptionType = .total
                case .home: consumptionType = .home
                case .homeDiscount: consumptionType = .homeDiscount
                case .homeRefunded: consumptionType = .homeRefunded
                case .charging: consumptionType = .charging
                case .chargingDiscount: consumptionType = .chargingDiscount
                case .chargingRefunded: consumptionType = .chargingRefunded
                case .refundingOtherPlan: consumptionType = .refundingOtherPlan
                }
                
                let home = HomeConsumption(
                    name: dto.name,
                    validFrom: dto.validFrom,
                    validUntil: dto.validUntil,
                    consumption: consumption,
                    consumptionType: consumptionType,
                    associatedLocation: location,
                    comment: dto.comment
                )
                home.id = dto.id
                modelContext.insert(home)
                homeConsumptionsById[dto.id] = home
                report.homeConsumptions += 1
            }

            // Insert price elements
            for dto in backup.priceElements {
                let existingPriceElements: [PriceElement] = (try? modelContext.fetch(FetchDescriptor<PriceElement>())) ?? []
                if existingPriceElements.contains(where: { $0.id == dto.id }) {
                    continue
                }

                // Map type
                let type: PriceElement.PriceElementType
                switch dto.type {
                case .daily:
                    type = .daily
                case .once:
                    type = .once
                case .byConsumption(let energyUnitSymbol):
                    type = .byConsumption(energyUnitSymbol: energyUnitSymbol)
                }

                let pe = PriceElement(label: dto.label, amount: dto.amount, inclVAT: dto.isGross, type: type, vatRate: dto.vatRate)
                pe.id = dto.id

                if let homeId = dto.homeConsumptionId, let home = homeConsumptionsById[homeId] {
                    pe.homeConsumption = home
                } else if let homeId = dto.homeConsumptionId {
                    // try to resolve from prefetched existing ones
                    if let existingHome = existingHomeConsumptionsById[homeId] {
                        pe.homeConsumption = existingHome
                    }
                }

                modelContext.insert(pe)
                priceElementsById[dto.id] = pe
                report.priceElements += 1
            }

            // Insert charging sessions
            for dto in backup.chargingSessions {
                let existingSessions: [ChargingSession] = (try? modelContext.fetch(FetchDescriptor<ChargingSession>())) ?? []
                if existingSessions.contains(where: { $0.id == dto.id }) {
                    continue
                }

                // Map calc method
                let calcMethod: ChargingSession.CostCalculationMethod
                switch dto.costCalculationMethod {
                case .absolute: calcMethod = .absolute
                case .specific: calcMethod = .specific
                case .both: calcMethod = .both
                case .none: calcMethod = .none
                }

                // Find plan
                let plan = dto.chargingCostPlanId.flatMap { plansById[$0] } ?? dto.chargingCostPlanId.flatMap { existingPlansById[$0] }

                // Related home consumption
                let relatedHome = dto.relatedHomeConsumptionId.flatMap { homeConsumptionsById[$0] } ?? dto.relatedHomeConsumptionId.flatMap { existingHomeConsumptionsById[$0] }

                let chargedEnergy = Measurement<UnitEnergy>(value: dto.chargedEnergyKWh, unit: .kilowattHours)

                // Ensure fallback charging cost plan (and its placeholder car/charger) are created and inserted into the context
                let sessionPlan: ChargingCostPlan
                if let existingPlan = plan {
                    sessionPlan = existingPlan
                } else {
                    // create placeholder car and charger and insert them
                    let fallbackCar = Car(make: "", model: "")
                    modelContext.insert(fallbackCar)
                    let fallbackCharger = Charger(name: dto.id.uuidString)
                    modelContext.insert(fallbackCharger)
                    let fallbackPlan = ChargingCostPlan(car: fallbackCar, charger: fallbackCharger, planType: .individual)
                    modelContext.insert(fallbackPlan)
                    sessionPlan = fallbackPlan
                }

                let session = ChargingSession(
                    startTime: dto.startTime,
                    endTime: dto.endTime,
                    chargedEnergy: chargedEnergy,
                    chargingCostPlan: sessionPlan,
                    chargingCost: dto.chargingCost,
                    specificChargingCost: dto.specificChargingCost,
                    costCalculationMethod: calcMethod,
                    mileage: dto.mileageKilometer == nil ? nil : Measurement<UnitLength>(value: dto.mileageKilometer!, unit: .kilometers),
                    initialSOC: dto.initialSOC,
                    finalSOC: dto.finalSOC,
                    comment: dto.comment
                )
                session.id = dto.id

                if let related = relatedHome {
                    session.relatedHomeConsumption = related
                }

                modelContext.insert(session)
                sessionsById[dto.id] = session
                report.chargingSessions += 1
            }

            // Insert charging session templates
            for dto in backup.chargingSessionTemplates {
                // chargingSessionId is a PersistentIdentifier (same as UUID in our export)
                // Try to resolve session
                if let session = sessionsById[dto.chargingSessionId] {
                    let template = ChargingSessionTemplate(name: dto.name, chargingSession: session)
                    modelContext.insert(template)
                    report.chargingSessionTemplates += 1
                } else {
                    // If session not found, still create template without session
                    let template = ChargingSessionTemplate(name: dto.name, chargingSession: nil)
                    modelContext.insert(template)
                    report.chargingSessionTemplates += 1
                }
            }

            // Optionally apply user settings snapshot
            if let settings = backup.userSettings {
                UserSettings.shared.measurementSystemIdentifier = settings.measurementSystem
                UserSettings.shared.currencyIdentifier = settings.currencyIdentifier
                UserSettings.shared.energyUnitSymbol = settings.energyUnitSymbol
                UserSettings.shared.powerUnitSymbol = settings.powerUnitSymbol
                UserSettings.shared.vatRate = settings.vatRate
                UserSettings.shared.displayGrossPrices = settings.displayGrossPrices
                report.userSettingsApplied = true
            }

            // Save context
            do {
                try modelContext.save()
            } catch {
                throw DataImportError.persistenceError(error)
            }

            return report
        } catch let err {
            throw DataImportError.decodingError(err)
        }
    }

    /// Convenience to import from a local file URL
    public static func importFromFile(url: URL, into modelContext: ModelContext) throws -> DataImportReport {
        let data = try Data(contentsOf: url)
        return try importFrom(data: data, into: modelContext)
    }
}
