//
//  PowerPriceAPIProtocol.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 26/04/2026.
//

import Foundation

protocol PowerPriceAPIProtocol {
    var name: String { get }
    var logoName: String { get }
    var websiteURL: URL? { get }
    var apiDocumentationURL: URL? { get }
    var supportsHistoricalPrices: Bool { get }
    var earliestAvailableDate: Date? { get }
    var latestAvailableDate: Date? { get }
    var requestURL: URL { get }
    var regions: [String]? { get }
    func fetchPowerPrices(from start: Date, to end: Date?, for regions: [String]?) async throws -> Data
    static func classString() -> String
}
