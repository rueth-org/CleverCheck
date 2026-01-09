//
//  ChargingSessionImporter.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 19/12/2025.
//

import Foundation
import SwiftData

public enum ChargingSessionImportError: Error {
    case decodingError(Error)
    case dateParseError(String)
    case noMatchingPlan(String)
    case persistenceError(Error)
}

public struct ChargingSessionImportReport {
    public var total: Int = 0
    public var imported: Int = 0
    public var skippedNoPlan: Int = 0
    public var skippedDuplicate: Int = 0
    public var failed: Int = 0
    public var errors: [String] = []
}

fileprivate struct ChargingSessionDTO: Codable {
    let endTime: String
    let chargingCostPlan: String?
    let chargedEnergyKWh: Double?
    let chargingCost: Double?
    let specificChargingCost: Double?
    let mileageKilometer: Double?
    let initialSOC: Double?
    let finalSOC: Double?

    enum CodingKeys: String, CodingKey {
        case endTime
        case chargingCostPlan
        case chargedEnergyKWh
        case chargingCost
        case specificChargingCost
        case mileageKilometer
        case initialSOC
        case finalSOC
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // endTime as string (required)
        self.endTime = try container.decode(String.self, forKey: .endTime)
        self.chargingCostPlan = try? container.decodeIfPresent(String.self, forKey: .chargingCostPlan)

        // Helper to decode numeric fields that may be Double or String with locale separators
        func decodeDoubleFlexible(for key: CodingKeys) -> Double? {
            // Try Double first
            if let d = try? container.decodeIfPresent(Double.self, forKey: key) {
                return d
            }
            // Then try String and parse
            if let s = try? container.decodeIfPresent(String.self, forKey: key) {
                return TextRecognizer.parseLocalizedDouble(s)
            }
            return nil
        }
        
        self.chargedEnergyKWh = decodeDoubleFlexible(for: .chargedEnergyKWh)
        self.chargingCost = decodeDoubleFlexible(for: .chargingCost)
        self.specificChargingCost = decodeDoubleFlexible(for: .specificChargingCost)
        self.mileageKilometer = decodeDoubleFlexible(for: .mileageKilometer)
        self.initialSOC = decodeDoubleFlexible(for: .initialSOC)
        self.finalSOC = decodeDoubleFlexible(for: .finalSOC)
    }
}

public struct ChargingSessionImporter {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Import from raw JSON Data.
    /// - Parameters:
    ///   - data: JSON data representing an array of objects matching the DTO shape.
    ///   - modelContext: the SwiftData ModelContext to insert objects into.
    ///   - assignedCar: (optional) Car to prefer for plan matching or fallback if no plan name is given.
    /// - Returns: an import report summarising the operation.
    static func importFrom(data: Data, into modelContext: ModelContext, assignedCar: Car? = nil) throws -> ChargingSessionImportReport {
        var report = ChargingSessionImportReport()

        let decoder = JSONDecoder()
        do {
            let dtos = try decoder.decode([ChargingSessionDTO].self, from: data)
            report.total = dtos.count

            // Preload existing plans and sessions to perform matching and deduplication in-memory
            let existingPlans: [ChargingCostPlan] = try modelContext.fetch(FetchDescriptor<ChargingCostPlan>())
            let existingSessions: [ChargingSession] = try modelContext.fetch(FetchDescriptor<ChargingSession>())

            for dto in dtos {
                // parse date
                guard let date = parseDate(dto.endTime) else {
                    report.failed += 1
                    report.errors.append("Invalid date string: \(dto.endTime)")
                    continue
                }

                // Find a matching plan if a name was provided
                var matchedPlan: ChargingCostPlan? = nil
                if let planName = dto.chargingCostPlan {
                    // If an assignedCar is provided, prefer plans belonging to that car
                    let plansToSearch = assignedCar == nil ? existingPlans : existingPlans.filter { $0.car?.persistentModelID == assignedCar!.persistentModelID }
                    matchedPlan = findPlan(named: planName, in: plansToSearch)
                } else if let assigned = assignedCar {
                    // No plan name provided: try to pick the first plan for the assigned car
                    matchedPlan = existingPlans.first(where: { $0.car?.id == assigned.id })
                }

                if matchedPlan == nil {
                    // If no matching plan found, skip this session and record an error
                    report.skippedNoPlan += 1
                    report.errors.append("No matching plan found for \(dto.chargingCostPlan ?? "(no plan provided)") at \(dto.endTime)")
                    continue
                }

                // Deduplicate by endTime + plan
                let isDuplicate = existingSessions.contains { session in
                    return session.endTime == date && session.chargingCostPlan?.id == matchedPlan?.id
                }
                if isDuplicate {
                    report.skippedDuplicate += 1
                    continue
                }

                // Build charged energy
                let energyMeasurement = Measurement<UnitEnergy>(value: dto.chargedEnergyKWh ?? 0.0, unit: .kilowattHours)

                // Create new ChargingSession
                let plan = matchedPlan!
                let newSession = ChargingSession(endTime: date, chargedEnergy: energyMeasurement, chargingCostPlan: plan)

                // mileage
                if let mileage = dto.mileageKilometer {
                    newSession.mileage = Measurement<UnitLength>(value: mileage, unit: .kilometers)
                    
                    // If mileage is entered, the finalSOC is 80%
                    newSession.finalSOC = 0.8
                }

                // store charging cost in currency of Locale.current
                if let chargingCost = dto.chargingCost {
                    let currency = Locale.current.currency?.identifier ?? "EUR"
                    let chargingCostObject = Cost(amount: chargingCost, currency: currency)
                    newSession.chargingCost = chargingCostObject
                }

                // store specific charging cost in currency of Locale.current
                if let specificChargingCost = dto.specificChargingCost {
                    let currency = Locale.current.currency?.identifier ?? "EUR"
                    let chargingCostObject = Cost(amount: specificChargingCost, currency: currency)
                    newSession.specificChargingCost = chargingCostObject
                }
                
                if dto.chargingCost != nil && dto.specificChargingCost != nil {
                    newSession.costCalculationMethod = .both
                } else if dto.chargingCost != nil {
                    newSession.costCalculationMethod = .absolute
                } else if dto.specificChargingCost != nil {
                    newSession.costCalculationMethod = .specific
                } else {
                    newSession.costCalculationMethod = .none
                }
                
                // initial SOC
                if let initialSOC = dto.initialSOC {
                    newSession.initialSOC = initialSOC
                }
                
                // final SOC
                if let finalSOC = dto.finalSOC {
                    newSession.finalSOC = finalSOC
                }

                modelContext.insert(newSession)
                report.imported += 1
            }

            do {
                try modelContext.save()
            } catch {
                throw ChargingSessionImportError.persistenceError(error)
            }

            return report
        } catch let err {
            throw ChargingSessionImportError.decodingError(err)
        }
    }

    /// Convenience to import from a local file URL
    static func importFromFile(url: URL, into modelContext: ModelContext, assignedCar: Car? = nil) throws -> ChargingSessionImportReport {
        let data = try Data(contentsOf: url)
        return try importFrom(data: data, into: modelContext, assignedCar: assignedCar)
    }

    // MARK: - Helpers

    static func parseDate(_ string: String) -> Date? {
        // Try ISO8601 first
        if let d = isoFormatter.date(from: string) {
            return d
        }
        // fallback to common formats
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let d = df.date(from: string) {
            return d
        }
        // Try without timezone
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = df.date(from: string) {
            return d
        }
        
        // Try European format
        df.dateFormat = "dd.MM.yyyy"
        return df.date(from: string)
    }

    private static func findPlan(named name: String, in plans: [ChargingCostPlan]) -> ChargingCostPlan? {
        // Try several human-friendly plan descriptions
        return plans.first(where: { plan in
            let candidates = [plan.descriptionLong, plan.descriptionShort, plan.descriptionLongNoCar, plan.descriptionShortNoCar]
            return candidates.contains(where: { $0 == name })
        })
    }
}
