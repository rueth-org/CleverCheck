//
//  HomeConsumptionImporter.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 30/12/2025.
//

import Foundation
import SwiftData

public enum PriceElementImportError: Error {
    case decodingError(Error)
    case dateParseError(String)
    case noMatchingHomeConsumption(String)
    case persistenceError(Error)
}

public struct PriceElementImportReport {
    public var total: Int = 0
    public var imported: Int = 0
    public var skippedNoHomeConsumption: Int = 0
    public var skippedDuplicate: Int = 0
    public var skippedUnknownType: Int = 0
    public var failed: Int = 0
    public var errors: [String] = []
}

fileprivate struct PriceElementDTO: Codable {
    let homeConsumptionName: String
    let homeConsumptionStartDate: String
    let label: String
    let amount: Double
    let type: String
    let isGross: String
    let vatRate: Double
    
    enum CodingKeys: String, CodingKey {
        case homeConsumptionName
        case homeConsumptionStartDate
        case label
        case amount
        case type
        case isGross
        case vatRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // label as string (required)
        self.label = try container.decode(String.self, forKey: .label)
        
        // type as string (required)
        self.type = try container.decode(String.self, forKey: .type)
        
        // homeConsumptionName and homeConsumptionStartDate as string (required)
        self.homeConsumptionName = try container.decode(String.self, forKey: .homeConsumptionName)
        self.homeConsumptionStartDate = try container.decode(String.self, forKey: .homeConsumptionStartDate)
        
        // isGross as string
        self.isGross = try container.decode(String.self, forKey: .isGross)
        
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
        
        // amount as double (required)
        if let c = decodeDoubleFlexible(for: .amount) {
            self.amount = c
        } else {
            self.amount = 0.0
        }
        
        // vatRate as double (required)
        if let c = decodeDoubleFlexible(for: .vatRate) {
            self.vatRate = c
        } else {
            self.vatRate = 0.25
        }
    }
}

public struct PriceElementImporter {
    /// Import from raw JSON Data.
    /// - Parameters:
    ///   - data: JSON data representing an array of objects matching the DTO shape.
    ///   - modelContext: the SwiftData ModelContext to insert objects into.
    /// - Returns: an import report summarising the operation.
    static func importFrom(data: Data, into modelContext: ModelContext) throws -> PriceElementImportReport {
        var report = PriceElementImportReport()

        let decoder = JSONDecoder()
        do {
            let dtos = try decoder.decode([PriceElementDTO].self, from: data)
            report.total = dtos.count

            // Preload existing homeConsumptions to perform matching
            let existingHomeConsumptions: [HomeConsumption] = try modelContext.fetch(FetchDescriptor<HomeConsumption>())
            
            for dto in dtos {
                // parse start date
                guard let startDate = ChargingSessionImporter.parseDate(dto.homeConsumptionStartDate) else {
                    report.failed += 1
                    report.errors.append("Invalid homeConsumptionStartDate string: \(dto.homeConsumptionStartDate)")
                    continue
                }
                
                // Find a matching homeConsumption
                guard let matchedHomeConsumption = existingHomeConsumptions.first(where: {
                    $0.name == dto.homeConsumptionName && $0.validFrom == startDate
                }) else {
                    // If no matching homeConsumption found, skip this session and record an error
                    report.skippedNoHomeConsumption += 1
                    report.errors.append("No matching home consumption found for \(dto.homeConsumptionName) at \(dto.homeConsumptionStartDate)")
                    continue
                }
                
                // Deduplicate by label
                if let existingPriceElements = matchedHomeConsumption.priceElements {
                    let isDuplicate = existingPriceElements.contains { priceElement in
                        return priceElement.label == dto.label
                    }
                    if isDuplicate {
                        report.skippedDuplicate += 1
                        continue
                    }
                }

                // Parse bool string
                let isGross = Bool(dto.isGross) ?? false
                
                // Define type
                var priceElementType: PriceElement.PriceElementType
                switch dto.type {
                case "daily": priceElementType = .daily
                case "once": priceElementType = .once
                case "byConsumption": priceElementType = .byConsumption(energyUnitSymbol: UserSettings.shared.energyUnitSymbol)
                default:
                    report.skippedUnknownType += 1
                    report.errors.append("Unexpected type '\(dto.type)' in row: \(dto)")
                    continue
                }
                
                // Create new HomeConsumption
                let newPriceElement = PriceElement(label: dto.label, amount: Cost(amount: dto.amount), isGross: isGross, type: priceElementType, vatRate: dto.vatRate)
                
                // Assign to home consumption
                newPriceElement.homeConsumption = matchedHomeConsumption
                
                modelContext.insert(newPriceElement)
                report.imported += 1
            }

            do {
                try modelContext.save()
            } catch {
                throw PriceElementImportError.persistenceError(error)
            }

            return report
        } catch let err {
            throw HomeConsumptionImportError.decodingError(err)
        }
    }

    /// Convenience to import from a local file URL
    static func importFromFile(url: URL, into modelContext: ModelContext) throws -> PriceElementImportReport {
        let data = try Data(contentsOf: url)
        return try importFrom(data: data, into: modelContext)
    }

    // MARK: - Helpers
}
