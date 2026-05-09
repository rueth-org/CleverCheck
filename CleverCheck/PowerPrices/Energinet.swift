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
        enum CodingKeys: String, CodingKey {
            case timeUTC = "TimeUTC"
            case priceArea = "PriceArea"
            case dayAheadPriceEUR = "DayAheadPriceEUR"
            case dayAheadPriceDKK = "DayAheadPriceDKK"
        }
        
        var id: String { "Energinet_\(priceArea)_\(timeUTC)" }
        var timeUTC: Date
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
    var regions: [String] {
        return ["DE", "DK1", "DK2", "NO2", "SE3", "SE4"]
    }
    
    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()
    
    func fetchPowerPrices(from start: Date, to end: Date?, for regions: [String]?) async throws -> [PowerPrice] {
        // Request URL example: https://api.energidataservice.dk/dataset/DayAheadPrices?start=2025-11-01&end=2025-12-01&filter={"PriceArea":["DK1","DK2"]}
        var queryParts = [URLQueryItem]()
        let startValue = Energinet.dateFormatter.string(from: start)
        queryParts.append(URLQueryItem(name: "start", value: startValue))
        if let end {
            let endValue = Energinet.dateFormatter.string(from: end)
            queryParts.append(URLQueryItem(name: "end", value: endValue))
        }
        if let regions {
            var areas = "["
            for (i, region) in regions.enumerated() {
                if i > 0 { areas += "," }
                areas += "\"\(region)\""
            }
            areas += "]"
            let filterJSON = "{\"PriceArea\":\(areas)}"
            // Append raw JSON for filter (not percent-encoding the braces/quotes)
            queryParts.append(URLQueryItem(name: "filter", value: filterJSON))
        }

        // Build raw URL string
        guard var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) else {
            throw NSError(domain: "Energinet", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid request URL"])
        }
        components.queryItems = queryParts

        if let url = components.url {
            debugPrint("Energinet request URL: \(url.absoluteString)")
            let data = try Data(contentsOf: url)
            return try decode(data)
        }

        throw NSError(domain: "Energinet", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    }
    
    private func decode(_ data: Data) throws -> [PowerPrice] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withoutTimeZoneSeparator
        let response = try decoder.decode(EnerginetResponse.self, from: data)
        return response.records.map { record in
            PowerPrice(
                serviceName: self.name,
                region: record.priceArea,
                timeUTC: record.timeUTC,
                resolutionMinutes: Energinet.resolutionMinutes,
                pricePerKWh: Cost(amount: record.dayAheadPriceDKK / 1000, currency: "DKK")
            )
        }
    }
    
    class func classString() -> String {
        return NSStringFromClass(self)
    }
}

extension ParseStrategy where Self == Date.ISO8601FormatStyle {
    static var iso8601withoutTimeZoneSeparator: Self {
        .init(timeZoneSeparator: .omitted)
    }
}

extension JSONDecoder.DateDecodingStrategy {
    static let iso8601withoutTimeZoneSeparator = custom {
        let string = try $0.singleValueContainer().decode(String.self)

        // Some Energinet timestamps omit the trailing timezone marker (e.g. "2026-05-09T21:45:00").
        // The ISO8601 parser expects a timezone (like "Z" for UTC). If no timezone is present,
        // assume UTC and append "Z" before parsing.
        var parseString = string

        // If the string already contains a timezone indicator (Z or +/-offset), leave it alone.
        // This regex looks for a trailing Z or an offset like +02:00, -0200 or +02
        if parseString.range(of: "Z|[+\\-]\\d{2}:?\\d{2}|[+\\-]\\d{2}$", options: .regularExpression) == nil {
            parseString += "Z"
        }

        // Use the explicit Date initializer to avoid ambiguity
        return try Date(parseString, strategy: .iso8601withoutTimeZoneSeparator)
    }
}
