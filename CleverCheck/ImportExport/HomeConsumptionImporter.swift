//
//  HomeConsumptionImporter.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 30/12/2025.
//

import Foundation
import SwiftData

public enum HomeConsumptionImportError: Error {
    case decodingError(Error)
    case dateParseError(String)
    case persistenceError(Error)
}

public struct HomeConsumptionImportReport {
    public var total: Int = 0
    public var imported: Int = 0
    public var skippedDuplicate: Int = 0
    public var failed: Int = 0
    public var errors: [String] = []
}

fileprivate struct HomeConsumptionDTO: Codable {
    let name: String
    let validFrom: String
    let validUntil: String
    let consumptionKWh: Double
    let consumptionIncludedElsewhere: String
    let associatedLocation: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case validFrom
        case validUntil
        case consumptionKWh
        case consumptionIncludedElsewhere
        case associatedLocation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // name as string (required)
        self.name = try container.decode(String.self, forKey: .name)
        
        // validFrom and validUntil as string (required)
        self.validFrom = try container.decode(String.self, forKey: .validFrom)
        self.validUntil = try container.decode(String.self, forKey: .validUntil)
        
        // associatedLocation as string (optional)
        self.associatedLocation = try container.decodeIfPresent(String.self, forKey: .associatedLocation)
        
        // Helper to decode numeric fields that may be Double or String with locale separators
        func decodeDoubleFlexible(for key: CodingKeys) -> Double? {
            // Try Double first
            if let d = try? container.decodeIfPresent(Double.self, forKey: key) {
                return d
            }
            // Then try String and parse
            if let s = try? container.decodeIfPresent(String.self, forKey: key) {
                return ChargingSessionImporter.parseLocalizedDouble(s)
            }
            return nil
        }
        
        if let c = decodeDoubleFlexible(for: .consumptionKWh) {
            self.consumptionKWh = c
        } else {
            self.consumptionKWh = 0.0
        }
        
        self.consumptionIncludedElsewhere = try container.decode(String.self, forKey: .consumptionIncludedElsewhere)
    }
}

public struct HomeConsumptionImporter {
    /// Import from raw JSON Data.
    /// - Parameters:
    ///   - data: JSON data representing an array of objects matching the DTO shape.
    ///   - modelContext: the SwiftData ModelContext to insert objects into.
    /// - Returns: an import report summarising the operation.
    static func importFrom(data: Data, into modelContext: ModelContext) throws -> HomeConsumptionImportReport {
        var report = HomeConsumptionImportReport()

        let decoder = JSONDecoder()
        do {
            let dtos = try decoder.decode([HomeConsumptionDTO].self, from: data)
            report.total = dtos.count

            // Preload existing locations and homeConsumptions to perform matching and deduplication in-memory
            let existingLocations: [Location] = try modelContext.fetch(FetchDescriptor<Location>())
            let existingHomeConsumptions: [HomeConsumption] = try modelContext.fetch(FetchDescriptor<HomeConsumption>())
            
            for dto in dtos {
                // parse dates
                guard let validFrom = ChargingSessionImporter.parseDate(dto.validFrom) else {
                    report.failed += 1
                    report.errors.append("Invalid validFrom string: \(dto.validFrom)")
                    continue
                }
                
                guard let validUntil = ChargingSessionImporter.parseDate(dto.validUntil) else {
                    report.failed += 1
                    report.errors.append("Invalid validUntil string: \(dto.validUntil)")
                    continue
                }

                // Find a matching location if a name was provided
                var matchedLocation: Location? = nil
                if let locationName = dto.associatedLocation {
                    // If a locationName is provided, prefer plans belonging to that car
                    matchedLocation = findLocation(named: locationName, in: existingLocations)
                }

                // Deduplicate by validFrom + validUntil + name
                let isDuplicate = existingHomeConsumptions.contains { homeConsumption in
                    return homeConsumption.name == dto.name && homeConsumption.validFrom == validFrom && homeConsumption.validUntil == validUntil
                }
                if isDuplicate {
                    report.skippedDuplicate += 1
                    continue
                }

                // Build charged energy
                let energyMeasurement = Measurement<UnitEnergy>(value: dto.consumptionKWh, unit: .kilowattHours)
                
                // Parse bool string
                let consumptionIncludedElsewhere = Bool(dto.consumptionIncludedElsewhere) ?? false

                // Create new HomeConsumption
                let newHomeConsumption = HomeConsumption(name: dto.name, validFrom: validFrom, validUntil: validUntil, consumption: energyMeasurement, consumptionIncludedElsewhere: consumptionIncludedElsewhere)
                
                // associatedLocation
                if let matchedLocation {
                    newHomeConsumption.associatedLocation = matchedLocation
                }

                modelContext.insert(newHomeConsumption)
                report.imported += 1
            }

            do {
                try modelContext.save()
            } catch {
                throw HomeConsumptionImportError.persistenceError(error)
            }

            return report
        } catch let err {
            throw HomeConsumptionImportError.decodingError(err)
        }
    }

    /// Convenience to import from a local file URL
    static func importFromFile(url: URL, into modelContext: ModelContext) throws -> HomeConsumptionImportReport {
        let data = try Data(contentsOf: url)
        return try importFrom(data: data, into: modelContext)
    }

    // MARK: - Helpers
    
    private static func findLocation(named name: String, in locations: [Location]) -> Location? {
        return locations.first(where: { $0.name == name })
    }
}
