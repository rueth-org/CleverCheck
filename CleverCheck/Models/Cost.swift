//
//  Cost.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 29/11/2025.
//

import Foundation

struct Cost: Codable, Hashable {
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

extension Cost: AdditiveArithmetic {
    static var zero: Cost = Cost(amount: 0.0)
    
    static func + (lhs: Cost, rhs: Cost) -> Cost {
        let lhsConverted = lhs.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0
        let rhsConverted = rhs.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0
        return Cost(amount: lhsConverted + rhsConverted)
    }
    
    static func - (lhs: Cost, rhs: Cost) -> Cost {
        let lhsConverted = lhs.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0
        let rhsConverted = rhs.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0
        return Cost(amount: lhsConverted - rhsConverted)
    }

    // Unary negation: return a Cost with the negated amount, preserving the currency
    static prefix func - (c: Cost) -> Cost {
        return Cost(amount: -c.amount, currency: c.currency)
    }
}
