//
//  Cost.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 29/11/2025.
//

import Foundation

struct Cost: Codable {
    enum CostError: Error {
        case currencyServiceUnavailable
        case currencyNotFound(currency: String)
    }
    
    var amount: Double
    var currency: String = UserSettings.shared.currencyIdentifier
    
    func converted(to currency: String) -> Cost? {
        if currency == self.currency {
            return self
        }

        guard let service = UserSettings.shared.currencyConverterService else {
            return nil
        }
        guard let fxRate = service.referenceRates.rate(fromCurrencyCode: self.currency, toCurrencyCode: currency) else {
            return nil
        }
        return Cost(amount: amount * fxRate, currency: currency)
    }
    
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "–"
    }
}

