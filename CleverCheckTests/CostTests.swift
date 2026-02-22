//
//  CostTests.swift
//  CleverCheckTests
//
//  Created by Ulrich Rüth on 21/02/2026.
//

import Foundation
import Testing
@testable import CleverCheck

@Suite("Cost struct")
struct CostTests {
    @Test("Initialization sets amount and currency")
    func testInit() async throws {
        let cost = Cost(amount: 10.0, currency: "USD")
        #expect(cost.amount == 10.0)
        #expect(cost.currency == "USD")
    }

    @Test("Converted to same currency returns self")
    func testConversionToSameCurrency() async throws {
        let cost = Cost(amount: 5.0, currency: "EUR")
        let result = cost.converted(to: "EUR")
        #expect(result == cost)
    }

    @Test("Converted to other currency uses service rate")
    func testConversionToOtherCurrency() async throws {
        let original = Cost(amount: 10.0, currency: "USD")
        
        // Create the service with test data
        try await UserSettings.shared.loadCurrencyConverterService(data: testXMLData)
        
        let converted = original.converted(to: "EUR")
        #expect(converted?.amount == 10.0 / 1.2059)
        #expect(converted?.currency == "EUR")
    }

    @Test("Conversion returns nil if service unavailable")
    func testConversionNoService() async throws {
        UserSettings.shared.currencyConverterService = nil
        let original = Cost(amount: 7.0, currency: "USD")
        let converted = original.converted(to: "EUR")
        #expect(converted == nil)
    }

    @Test("Conversion returns nil if no rate available")
    func testConversionNoRate() async throws {
        let original = Cost(amount: 7.0, currency: "USD")
        
        // Create the service with test data
        try await UserSettings.shared.loadCurrencyConverterService(data: testXMLData)
        
        let converted = original.converted(to: "ABC")
        #expect(converted == nil)
    }

    @Test("Formatted returns currency string")
    func testFormatted() async throws {
        let cost = Cost(amount: 12.5, currency: "USD")
        let result = cost.formatted()
        #expect(result.contains("$") || result.contains("USD"))
    }

    @Test("AdditiveArithmetic zero is zero")
    func testZero() async throws {
        let zero = Cost.zero
        #expect(zero.amount == 0.0)
    }

    @Test("Addition adds amounts after conversion")
    func testAddition() async throws {
        UserSettings.shared.currencyIdentifier = "EUR"
        
        // Create the service with test data
        try await UserSettings.shared.loadCurrencyConverterService(data: testXMLData)
        
        let lhs = Cost(amount: 1, currency: "USD")
        let rhs = Cost(amount: 3, currency: "EUR")
        let result = lhs + rhs
        // 1 USD = 1/1.2059 EUR
        #expect(result.amount == 1 / 1.2059 + 3.0)
    }

    @Test("Subtraction subtracts amounts after conversion")
    func testSubtraction() async throws {
        UserSettings.shared.currencyIdentifier = "EUR"
        
        // Create the service with test data
        try await UserSettings.shared.loadCurrencyConverterService(data: testXMLData)
        
        let lhs = Cost(amount: 4, currency: "USD")
        let rhs = Cost(amount: 3, currency: "EUR")
        let result = lhs - rhs
        // 4 USD = 4/1.2059 EUR
        #expect(result.amount == 4 / 1.2059 - 3.0)
    }
    
    private let testXMLData = """
        <gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01" xmlns="https://expenses.cash/eurofxref">
        <gesmes:subject>Reference rates</gesmes:subject>
        <gesmes:Sender>
        <gesmes:name>Expenses</gesmes:name>
        </gesmes:Sender>
        <Cube>
        <Cube time="2021-05-07">
        <Cube currency="USD" rate="1.2059"/>
        <Cube currency="JPY" rate="131.76"/>
        <Cube currency="BGN" rate="1.9558"/>
        <Cube currency="CZK" rate="25.682"/>
        <Cube currency="DKK" rate="7.4361"/>
        <Cube currency="GBP" rate="0.86810"/>
        <Cube currency="HUF" rate="358.01"/>
        <Cube currency="PLN" rate="4.5754"/>
        <Cube currency="RON" rate="4.9265"/>
        <Cube currency="SEK" rate="10.1263"/>
        <Cube currency="CHF" rate="1.0963"/>
        <Cube currency="ISK" rate="150.50"/>
        <Cube currency="NOK" rate="10.0125"/>
        <Cube currency="HRK" rate="7.5345"/>
        <Cube currency="RUB" rate="89.4671"/>
        <Cube currency="TRY" rate="10.0019"/>
        <Cube currency="AUD" rate="1.5523"/>
        <Cube currency="BRL" rate="6.3801"/>
        <Cube currency="CAD" rate="1.4689"/>
        <Cube currency="CNY" rate="7.7809"/>
        <Cube currency="HKD" rate="9.3661"/>
        <Cube currency="IDR" rate="17208.37"/>
        <Cube currency="ILS" rate="3.9438"/>
        <Cube currency="INR" rate="88.6375"/>
        <Cube currency="KRW" rate="1350.52"/>
        <Cube currency="MXN" rate="24.2006"/>
        <Cube currency="MYR" rate="4.9587"/>
        <Cube currency="NZD" rate="1.6730"/>
        <Cube currency="PHP" rate="57.747"/>
        <Cube currency="SGD" rate="1.6061"/>
        <Cube currency="THB" rate="37.588"/>
        <Cube currency="ZAR" rate="17.1863"/>
        </Cube>
        </Cube>
        </gesmes:Envelope>
        """.data(using: .utf8)!
}

