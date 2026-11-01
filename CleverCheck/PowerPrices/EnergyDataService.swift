//
//  EnergyDataService.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 28/04/2026.
//

import Foundation

/// Service responsible for retrieving energy data (day-ahead prices) from a remote JSON repository
/// or, if missing, delegating to the configured PowerPriceAPI implementation and caching the result.
final class EnergyDataService {
    enum EnergyDataError: Error {
        case missingServiceName
        case noRelatedHomeConsumption
        case noRelatedRefundingHomeConsumption
        case invalidRelatedHomeConsumptionType
        case multipleRelatedHomeConsumptions([String])
        case serviceClassNotFound(String)
        case invalidData(String)
        case invalidURL(String)
        case invalidResponse(String)
        case notFound(String)
        case cannotDetermineDuration
        case noLocation
        case cannotDetermineTime(String)
        
        // Provide localized error descriptions by conforming to LocalizedError and returning
        // NSLocalizedString keys. Add translations in your Localizable.strings / .xcstrings files.
        var errorDescription: String {
            switch self {
            case .missingServiceName:
                return NSLocalizedString("The location does not specify a power price service name.", comment: "")
            case .noRelatedHomeConsumption:
                return NSLocalizedString("No related home consumption found for the charging session.", comment: "")
            case .noRelatedRefundingHomeConsumption:
                return NSLocalizedString("No related refunding home consumption found for the charging session.", comment: "")
            case .invalidRelatedHomeConsumptionType:
                return NSLocalizedString("The related home consumption is not of the expected type total or home.", comment: "")
            case .multipleRelatedHomeConsumptions(let descriptions):
                let format = NSLocalizedString("Multiple related home consumptions found for the charging session: %@", comment: "")
                return String(format: format, descriptions.joined(separator: ", "))
            case .serviceClassNotFound(let name):
                let format = NSLocalizedString("No PowerPriceAPI class found with name '%@'.", comment: "")
                return String(format: format, name)
            case .invalidData(let description):
                let format = NSLocalizedString("Invalid data: '%@'.", comment: "")
                return String(format: format, description)
            case .invalidURL(let url):
                let format = NSLocalizedString("Invalid URL: '%@'.", comment: "")
                return String(format: format, url)
            case .invalidResponse(let response):
                let format = NSLocalizedString("Received an invalid response from the server: %@.", comment: "")
                return String(format: format, response)
            case .notFound(let item):
                let format = NSLocalizedString("%@ not found.", comment: "")
                return String(format: format, item)
            case .cannotDetermineDuration:
                return NSLocalizedString("Cannot determine duration from the provided data.", comment: "")
            case .noLocation:
                return NSLocalizedString("No location information available.", comment: "")
            case .cannotDetermineTime(let timeString):
                let format = NSLocalizedString("Cannot determine time from '%@'.", comment: "")
                return String(format: format, timeString)
            }
        }
    }
    
    private struct PowerPriceDBRecords: Codable {
        let records: [PowerPriceDBEntry]
    }
    
    fileprivate struct PowerPriceDBEntry: Codable {
        let serviceName: String
        let region: String
        let timeUTC: String
        let resolutionMinutes: Int
        let priceKwh: Double
        let currency: String
        
        enum CodingKeys: String, CodingKey {
            case serviceName = "servicename"
            case region
            case timeUTC = "time_utc"
            case resolutionMinutes = "resolution_minutes"
            case priceKwh = "price_kwh"
            case currency
        }
    }

    /// Shared singleton instance
    static let shared = EnergyDataService()

    private let powerPriceDBUrl = "https://energydata.rueth.info/api.php/records/powerprice"
    private let mysqlDatetimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // MySQL DATETIME format
        formatter.locale = Locale(identifier: "en_US_POSIX") // Ensures consistent parsing
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Adjust if needed
        return formatter
    }()
    
    // List of all available energy data providers (classes conforming to PowerPriceAPIProtocol)
    let availableProviders: [PowerPriceAPIProtocol] = [Energinet()]
    
    // Prevent external instantiation
    private init() {}

    /// Returns the power prices for the given location and time range. Tries to read month JSON files
    /// from the configured webserver first. For any month file that is missing or does not contain
    /// data for the requested range, the corresponding PowerPrice provider's `fetchPowerPrices` is
    /// called for that month. Fetched data is written back (attempts HTTP PUT; falls back to local
    /// cache file) and the collected prices covering the requested range are returned.
    func dayAheadPrices(for location: Location, from start: Date, to end: Date) async throws -> [PowerPrice] {
        guard let serviceName = location.powerPriceServiceName, !serviceName.isEmpty else {
            throw EnergyDataError.missingServiceName
        }

        if end < start {
            throw EnergyDataError.invalidData("Start date must be before end date")
        }

        let region = location.powerPriceRegion
        let calendar = Calendar.current

        // Compute first day of start's month
        let startComps = calendar.dateComponents([.year, .month], from: start)
        guard let startOfFirstMonth = calendar.date(from: DateComponents(year: startComps.year, month: startComps.month, day: 1)) else {
            throw EnergyDataError.invalidData("Cannot determine start of first month")
        }

        var collected: [PowerPrice] = []
        var providerInstance: PowerPriceAPIProtocol? = nil

        var currentMonth = startOfFirstMonth
        while currentMonth <= end {
            let comps = calendar.dateComponents([.year, .month], from: currentMonth)
            guard let year = comps.year, let month = comps.month else { break }
            let monthString = String(format: "%04d-%02d", year, month)
            let filename = "\(serviceName)_\(monthString).json"
            
            // Try to load the prices from server
            var success = false
            do {
                if let prices = try await fetchPrices(from: powerPriceDBUrl, provider: serviceName, region: region, from: start, to: end) {
                    collected.append(contentsOf: prices)
                    success = true
                }
            } catch {
                debugPrint("Failed to load from \(powerPriceDBUrl): \(error)")
            }
            
            // If not successful, try to load from local cache before asking the provider
            if !success {
                if let cached = try? loadPricesFromLocalCache(filename, region: region, from: start, to: end) {
                    collected.append(contentsOf: cached)
                } else {
                    // Need to fetch from provider for this month
                    if providerInstance == nil {
                        guard let providerType = findProviderType(named: serviceName) else {
                            throw EnergyDataError.serviceClassNotFound(serviceName)
                        }
                        providerInstance = providerType.init()
                    }
                    
                    // Determine month range for provider call
                    guard let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
                        throw EnergyDataError.invalidData("Cannot determine start of month")
                    }
                    guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                        throw EnergyDataError.invalidData("Cannot determine start of next month")
                    }
                    
                    let fetchedPrices = try await providerInstance!.fetchPowerPrices(from: startOfMonth, to: startOfNextMonth, for: region != nil ? [region!] : nil)
                    collected.append(contentsOf: fetchedPrices)
                    
                    // Try to write back to remote; if it fails, write local cache
                    do {
                        try await writePrices(fetchedPrices, toRemoteURL: powerPriceDBUrl)
                    } catch {
                        debugPrint("Failed to write prices to remote, error: \(error)")
                        try writePricesToLocalCache(fetchedPrices, filename: filename)
                    }
                }
            }

            // advance to next month
            guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { break }
            currentMonth = next
        }

        // Filter collected prices to the requested time window and region
        let filtered = filterPrices(collected, from: start, to: end, region: region)
        return filtered
    }

    // MARK: - Helpers

    private func findMatchingPrice(in prices: [PowerPrice], for time: Date, region: String?) -> PowerPrice? {
        let calendar = Calendar.current
        // Match using timeLocal. Match by hour granularity.
        for price in prices where (region == nil || price.region == region) {
            if calendar.isDate(price.timeLocal, equalTo: time, toGranularity: price.granularity) {
                return price
            }
        }
        return nil
    }

    func findProviderType(named name: String) -> PowerPriceAPIProtocol.Type? {
        // Try module-prefixed name first, then bare name
        let candidates: [String]
        if let module = Bundle.main.infoDictionary?["CFBundleName"] as? String {
            candidates = ["\(module).\(name)", name]
        } else {
            candidates = [name]
        }

        for candidate in candidates {
            if let cls = NSClassFromString(candidate) as? PowerPriceAPIProtocol.Type {
                return cls
            }
        }

        return nil
    }

    private func filterPrices(_ prices: [PowerPrice], from start: Date, to end: Date, region: String?) -> [PowerPrice] {
        // First, restrict to the requested region (if any) then sort by timeLocal ascending
        let regionFiltered = prices.filter { price in
            if let r = region, price.region != r { return false }
            return true
        }

        let sorted = regionFiltered.sorted(by: { $0.timeUTC < $1.timeUTC })

        var result: [PowerPrice] = []

        // Include the last price element strictly before the start (if any)
        if let lastBefore = sorted.last(where: { $0.timeUTC < start }) {
            result.append(lastBefore)
        }

        // Then include all elements within [start, end]
        let inRange = sorted.filter { $0.timeUTC >= start && $0.timeUTC <= end }
        result.append(contentsOf: inRange)

        return result
    }

    private func writePrices(_ prices: [PowerPrice], toRemoteURL url: String) async throws {
        guard let url = URL(string: url) else {
            throw EnergyDataError.invalidURL(url)
        }
        
        // Ignore if records are already in database
        let queryItem = URLQueryItem(name: "ignore", value: nil)
        let urlInsertIgnore = url.appending(queryItems: [queryItem])
        
        // Convert PowerPrice array to PowerPriceDBEntry array
        let entries = prices.map({ PowerPriceDBEntry(from: $0) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)

        var req = URLRequest(url: urlInsertIgnore)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw EnergyDataError.invalidResponse(String(http.statusCode))
        }
    }

    private func fetchPrices(from url: String, provider: String, region: String?, from: Date, to: Date) async throws -> [PowerPrice]? {
        let url = try filterRecords(baseUrl: url, provider: provider, region: region, from: from, to: to)
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { return nil }
            guard (200...299).contains(http.statusCode) else { throw EnergyDataError.invalidResponse(String(http.statusCode)) }
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let powerPriceDBRecords = try decoder.decode(PowerPriceDBRecords.self, from: data)
        
        // Map PowerPriceDBEntry to PowerPrice
        let powerPrices = try powerPriceDBRecords.records.map({ try PowerPrice(from: $0) })
        
        if checkTimePeriodCoverage(powerPrices, for: region, from: from, to: to) {
            return powerPrices
        } else {
            return nil
        }
    }

    private func writePricesToLocalCache(_ prices: [PowerPrice], filename: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(prices)

        let fm = FileManager.default
        let cacheDir = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = cacheDir.appending(path: "EnergyData", directoryHint: .isDirectory)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let fileURL = dir.appendingPathComponent(filename)
        debugPrint("Writing energy data to local cache at \(fileURL.path)")
        try data.write(to: fileURL, options: .atomic)
    }

    private func loadPricesFromLocalCache(_ filename: String, region: String?, from: Date, to: Date) throws -> [PowerPrice]? {
        let fm = FileManager.default
        let cacheDir = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = cacheDir.appendingPathComponent("EnergyData", isDirectory: true)
        let fileURL = dir.appendingPathComponent(filename)

        if !fm.fileExists(atPath: fileURL.path) {
            return nil
        }

        debugPrint("Loading energy data from local cache at \(fileURL.path)")
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let powerPrices = try decoder.decode([PowerPrice].self, from: data)
        
        if checkTimePeriodCoverage(powerPrices, for: region, from: from, to: to) {
            return powerPrices
        } else {
            return nil
        }
    }
    
    /// Checks if the power price array contains covers the from-to range, otherwise the data might be outdated.
    /// - Parameters:
    ///   - powerPrices: The array of power prices to be checked.
    ///   - region: The region, nil if unknown or irrelevant.
    ///   - from: The start of the time period.
    ///   - to: The end of the time period.
    /// - Returns: True if power prices array is up-to-date, false otherwise.
    private func checkTimePeriodCoverage(_ powerPrices: [PowerPrice], for region: String?, from: Date, to: Date) -> Bool {
        let sortedPowerPrices = region != nil ? powerPrices.filter { $0.region == region! }.sorted(by: { $0.timeUTC < $1.timeUTC }) : powerPrices.sorted(by: { $0.timeUTC < $1.timeUTC })
        
        if let firstPrice = sortedPowerPrices.first, let lastPrice = sortedPowerPrices.last {
            let firstPriceTime = firstPrice.timeUTC
            
            // We need to add the resolution in minutes to the last price depending on its granularity
            let lastPriceTime = Calendar.current.date(byAdding: .minute, value: lastPrice.resolutionMinutes, to: lastPrice.timeUTC)!
            
            // The time of the last price needs to be later or equal than the current time
            if firstPriceTime <= from && to <= lastPriceTime {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    // Function to convert MySQL DATETIME string to Swift Date
    fileprivate func mysqlDatetimeToDate(_ datetimeString: String) -> Date? {
        mysqlDatetimeFormatter.date(from: datetimeString)
    }
    
    // Function to convert Swift Date to MySQL DATETIME string
    fileprivate func dateToMysqlDatetime(_ dateUTC: Date) -> String {
        mysqlDatetimeFormatter.string(from: dateUTC)
    }
    
    /// Appends filters to the base URL according to https://github.com/mevdschee/php-crud-api
    /// - Parameters:
    ///   - baseUrl: The base URL to apply filters on
    ///   - provider: The provider
    ///   - region: The region
    ///   - from: Start date and time
    ///   - to: End date and time
    ///   - timeZone: The time zone the dates are in
    /// - Returns: A URL string with appended filters
    private func filterRecords(baseUrl: String, provider: String, region: String? = nil, from: Date? = nil, to: Date? = nil) throws -> URL {
        guard let url = URL(string: baseUrl) else {
            throw EnergyDataService.EnergyDataError.invalidURL(baseUrl)
        }
        
        var queryItems = [URLQueryItem]()
        // Filter servicename by provider
        queryItems.append(URLQueryItem(name: "filter", value: "servicename,eq,\(provider)"))
        
        // Filter by region
        if let region = region {
            queryItems.append(URLQueryItem(name: "filter", value: "region,eq,\(region)"))
        }
        
        // Filter entries later or equal than from
        if let from = from {
            queryItems.append(URLQueryItem(name: "filter", value: "time_utc,ge,\(EnergyDataService.shared.dateToMysqlDatetime(from))"))
        }
        
        // Filter entries earlier or equal than to
        if let to = to {
            queryItems.append(URLQueryItem(name: "filter", value: "time_utc,le,\(EnergyDataService.shared.dateToMysqlDatetime(to))"))
        }
        
        return url.appending(queryItems: queryItems)
    }
}

extension EnergyDataService.PowerPriceDBEntry {
    init(from price: PowerPrice) {
        self.serviceName = price.serviceName
        self.region = price.region
        self.timeUTC = EnergyDataService.shared.dateToMysqlDatetime(price.timeUTC)
        self.resolutionMinutes = price.resolutionMinutes
        self.priceKwh = price.pricePerKWh.amount
        self.currency = price.pricePerKWh.currency
    }
}

extension PowerPrice {
    fileprivate init(from dbEntry: EnergyDataService.PowerPriceDBEntry) throws {
        guard let date = EnergyDataService.shared.mysqlDatetimeToDate(dbEntry.timeUTC) else {
            throw EnergyDataService.EnergyDataError.cannotDetermineTime(dbEntry.timeUTC)
        }
        
        self.serviceName = dbEntry.serviceName
        self.region = dbEntry.region
        self.timeUTC = date
        self.resolutionMinutes = dbEntry.resolutionMinutes
        self.pricePerKWh = Cost(amount: dbEntry.priceKwh, currency: dbEntry.currency)
        self.timeZone = .current
    }
}

