//
//  Energinet.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 26/04/2026.
//

import Foundation

final class Energinet: PowerPriceAPIProtocol {
    struct EnerginetResponse: Codable {
        var records: [EnerginetRecord]
    }
    
    struct EnerginetRecord: Codable, Identifiable {
        enum Response: String, CodingKey {
            case timeUTC = "TimeUTC"
            case timeDK = "TimeDK"
            case priceArea = "PriceArea"
            case dayAheadPriceEUR = "DayAheadPriceEUR"
            case dayAheadPriceDKK = "DayAheadPriceDKK"
        }
        
        var id: String { "Energinet_\(priceArea)_\(timeDK)" }
        var timeUTC: Date
        var timeDK: Date
        var priceArea: String
        var dayAheadPriceEUR: Double
        var dayAheadPriceDKK: Double
    }
    
    static let currentDataModelVersion: String = "1"
    static let resolutionMinutes: Int = 15
    
    var name: String { "Energinet" }
    var logoName: String { "energinet" }
    var websiteURL: URL? { URL(string: "https://www.energidataservice.dk/")! }
    var apiDocumentationURL: URL? { URL(string: "https://www.energidataservice.dk/tso-electricity/api")! }
    var supportsHistoricalPrices: Bool { true }
    var earliestAvailableDate: Date? { Calendar.current.date(from: DateComponents(year: 2015, month: 10, day: 1)) }
    var latestAvailableDate: Date? { nil }
    var requestURL: URL { URL(string: "https://api.energidataservice.dk/dataset/DayAheadPrices")! }
    var regions: [String]? {
        return ["DE", "DK1", "DK2", "NO2", "SE3", "SE4"]
    }
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay]
        return formatter
    }()
    
    func fetchPowerPrices(from start: Date, to end: Date?, for regions: [String]?) async throws -> [PowerPrice] {
        // Request URL example: https://api.energidataservice.dk/dataset/DayAheadPrices?start=2025-11-01&end=2025-12-01&filter={"PriceArea":["DK1","DK2"]}
        var url = requestURL.appendingPathExtension("?start=\(Energinet.isoFormatter.string(from: start))")
        if let end {
            url.appendPathExtension("&end=\(Energinet.isoFormatter.string(from: end))")
        }
        if let regions {
            url.appendPathExtension("&filter={\"PriceArea\":[")
            for (i, region) in regions.enumerated() {
                if i > 0 {
                    url.appendPathExtension(",")
                }
                url.appendPathExtension("\"\(region)\"")
            }
            url.appendPathExtension("]}")
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }
    
    private func decode(_ data: Data) throws -> [PowerPrice] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(EnerginetResponse.self, from: data)
        return response.records.map { record in
            PowerPrice(
                serviceName: self.name,
                region: record.priceArea,
                timeUTC: record.timeUTC,
                timeLocal: record.timeDK,
                resolutionMinutes: Energinet.resolutionMinutes,
                price: Cost(amount: record.dayAheadPriceDKK, currency: "DKK")
            )
        }
    }
    
    class func classString() -> String {
        return NSStringFromClass(self)
    }
}
