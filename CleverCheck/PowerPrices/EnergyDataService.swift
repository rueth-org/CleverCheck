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
        case serviceClassNotFound(String)
        case invalidResponse
        case notFound
        case cannotDetermineDuration
        case noLocation
    }

    private let host = "https://energydata.rueth.info"

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
            throw EnergyDataError.invalidResponse
        }

        let region = location.powerPriceRegion
        let calendar = Calendar.current

        // Compute first day of start's month
        let startComps = calendar.dateComponents([.year, .month], from: start)
        guard let startOfFirstMonth = calendar.date(from: DateComponents(year: startComps.year, month: startComps.month, day: 1)) else {
            throw EnergyDataError.invalidResponse
        }

        var collected: [PowerPrice] = []
        var providerInstance: PowerPriceAPIProtocol? = nil

        var currentMonth = startOfFirstMonth
        while currentMonth <= end {
            let comps = calendar.dateComponents([.year, .month], from: currentMonth)
            guard let year = comps.year, let month = comps.month else { break }
            let monthString = String(format: "%04d-%02d", year, month)
            let filename = "\(serviceName)_\(monthString).json"
            guard let fileURL = URL(string: "\(host)/\(filename)") else {
                throw EnergyDataError.invalidResponse
            }

            // Try to load the JSON file from server
            if let prices = try? await fetchPricesFromURL(fileURL) {
                collected.append(contentsOf: prices)
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
                    throw EnergyDataError.invalidResponse
                }
                guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                    throw EnergyDataError.invalidResponse
                }

                let fetchedPrices = try await providerInstance!.fetchPowerPrices(from: startOfMonth, to: startOfNextMonth, for: region != nil ? [region!] : nil)
                collected.append(contentsOf: fetchedPrices)

                // Try to write back to remote; if it fails, write local cache
                do {
                    try await writePrices(fetchedPrices, toRemoteURL: fileURL)
                } catch {
                    try writePricesToLocalCache(fetchedPrices, filename: filename)
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

    private func fetchPricesFromURL(_ url: URL) async throws -> [PowerPrice]? {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { return nil }
            guard (200...299).contains(http.statusCode) else { throw EnergyDataError.invalidResponse }
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([PowerPrice].self, from: data)
    }

    private func findMatchingPrice(in prices: [PowerPrice], for time: Date, region: String?) -> PowerPrice? {
        let calendar = Calendar.current
        // Try to match using timeLocal first (if present), then timeUTC. Match by hour granularity.
        for price in prices where (region == nil || price.region == region) {
            if let local = price.timeLocal {
                if calendar.isDate(local, equalTo: time, toGranularity: .hour) {
                    return price
                }
            }
            if calendar.isDate(price.timeUTC, equalTo: time, toGranularity: .hour) {
                return price
            }
        }
        return nil
    }

    private func findProviderType(named name: String) -> PowerPriceAPIProtocol.Type? {
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
        return prices.filter { price in
            if let r = region, price.region != r { return false }
            let dateToCheck = price.timeLocal ?? price.timeUTC
            return dateToCheck >= start && dateToCheck <= end
        }
    }

    private func writePrices(_ prices: [PowerPrice], toRemoteURL url: URL) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(prices)

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw EnergyDataError.invalidResponse
        }
    }

    private func writePricesToLocalCache(_ prices: [PowerPrice], filename: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(prices)

        let fm = FileManager.default
        let cacheDir = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = cacheDir.appendingPathComponent("EnergyData", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let fileURL = dir.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
    }
}
