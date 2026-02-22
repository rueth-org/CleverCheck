//
//  CurrencyConverter.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 21/01/2026.
//

import Foundation
import CurrencyConverter

struct CurrencyConverterService {
    static func makeService(data: Data? = nil) async throws -> CurrencyConverterService {
        var converter: CurrencyConverter
        if let data = data {
            converter = CurrencyConverter(data: data)
        } else {
            converter = CurrencyConverter()
        }
        let rates = try await converter.fetch()
        return CurrencyConverterService(referenceRates: rates)
    }

    let referenceRates: ReferenceRates

    private init(referenceRates: ReferenceRates) {
        self.referenceRates = referenceRates
    }
}
