//
//  CurrencyConverter.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 21/01/2026.
//

import Foundation
import CurrencyConverter

struct CurrencyConverterService {
    static func makeService() async throws -> CurrencyConverterService {
        let converter = CurrencyConverter()
        let rates = try await converter.fetch()
        return CurrencyConverterService(referenceRates: rates)
    }

    let referenceRates: ReferenceRates

    private init(referenceRates: ReferenceRates) {
        self.referenceRates = referenceRates
    }
}
