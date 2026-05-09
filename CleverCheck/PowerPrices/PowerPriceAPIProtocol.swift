//
//  PowerPriceAPIProtocol.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 26/04/2026.
//

import Foundation

/// Protocol that power price provider classes must conform to.
protocol PowerPriceAPIProtocol {
    /// Version of the data model used by the provider implementation
    static var currentDataModelVersion: String { get }
    static var resolutionMinutes: Int { get }
    /// Default initializer requirement so implementations can be instantiated by name
    init()
    var name: String { get }
    var logoName: String { get }
    var websiteURL: URL? { get }
    var apiDocumentationURL: URL? { get }
    var supportsHistoricalPrices: Bool { get }
    var earliestAvailableDate: Date? { get }
    var latestAvailableDate: Date? { get }
    var requestURL: URL { get }
    var regions: [String] { get }
    /// Fetch power prices in the given time range for optional regions
    func fetchPowerPrices(from start: Date, to end: Date?, for regions: [String]?) async throws -> [PowerPrice]
    static func classString() -> String
}
