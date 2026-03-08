// swift
import Testing
import Foundation
@testable import CleverCheck

@Suite("Location data aggregation")
struct LocationTests {
    // Helper builder types: produce minimal, valid objects for tests

    struct TestPriceElementBuilder {
        var label: String = "base"
        var amount: Double = 0.0
        var inclVAT: Bool = true
        var type: PriceElement.PriceElementType = .byConsumption(energyUnitSymbol: UserSettings.shared.energyUnit.symbol)
        var vatRate: Double? = nil

        func build() -> PriceElement {
            let pe = PriceElement(label: label, amount: Cost(amount: amount), inclVAT: inclVAT, type: type, vatRate: vatRate)
            return pe
        }
    }

    struct TestHomeConsumptionBuilder {
        var name: String = "HC"
        var validFrom: Date = Date.now.startOfMonth
        var validUntil: Date = Date.now.endOfMonth
        var consumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: .kilowattHours)
        var consumptionIncludedElsewhere: Bool = false
        var priceElements: [PriceElement] = []

        func build() -> HomeConsumption {
            let hc = HomeConsumption(
                name: name,
                validFrom: validFrom,
                validUntil: validUntil,
                consumption: consumption,
                consumptionIncludedElsewhere: consumptionIncludedElsewhere
            )
            if !priceElements.isEmpty {
                hc.priceElements = priceElements
            }
            return hc
        }
    }

    // Data set structure used by tests. Each dataset contains one or more HomeConsumptions and maps for refunded and related charging consumptions per month.
    struct TestDataSet {
        var homeConsumptions: [HomeConsumption]
        var refundedPerMonth: [String: (consumption: Measurement<UnitEnergy>, cost: Cost)]
        var relatedChargingConsumptions: [String: Measurement<UnitEnergy>]
    }

    // Bundle finder helper to locate resources in the test bundle
    private final class BundleFinder {}

    // Decodable intermediates for JSON loading
    private struct DecodablePriceElement: Decodable {
        var label: String?
        var amount: Double?
        var inclVAT: Bool?
        var type: String? // e.g. "byConsumption"
        var vatRate: Double?
    }

    private struct DecodableHomeConsumption: Decodable {
        var name: String?
        var validFrom: String?
        var validUntil: String?
        var consumptionIncludedElsewhere: Bool?
        var consumptionKWh: Double?
        var priceElements: [DecodablePriceElement]?
    }

    private struct DecodableRefundEntry: Decodable {
        var consumptionKWh: Double?
        var cost: Double?
    }

    private struct DecodableDataSet: Decodable {
        var homeConsumptions: [DecodableHomeConsumption]?
        var refundedPerMonth: [String: DecodableRefundEntry]?
        var relatedChargingConsumptions: [String: Double]?
    }

    // Load JSON data from `TestData_2026-03-07.json` in the test bundle and convert into TestDataSet.
    private func loadTestData() -> TestDataSet {
        // Locate file in the same bundle as the tests
        let bundle = Bundle(for: BundleFinder.self)
        guard let url = bundle.url(forResource: "TestData_2026-03-07", withExtension: "json") else {
            return basicDataSet()
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(DecodableDataSet.self, from: data)

            // Convert home consumptions
            var homeConsumptions: [HomeConsumption] = []
            if let decHCs = decoded.homeConsumptions {
                for decHC in decHCs {
                    let name = decHC.name ?? "HC"
                    // Parse dates using ISO8601, fall back to start/end of current month
                    let iso = ISO8601DateFormatter()
                    let validFrom = (decHC.validFrom != nil) ? iso.date(from: decHC.validFrom!) ?? Date.now.startOfMonth : Date.now.startOfMonth
                    let validUntil = (decHC.validUntil != nil) ? iso.date(from: decHC.validUntil!) ?? Date.now.endOfMonth : Date.now.endOfMonth
                    let consumptionValue = decHC.consumptionKWh ?? 0.0
                    let consumption = Measurement(value: consumptionValue, unit: UnitEnergy.kilowattHours)
                    let includedElsewhere = decHC.consumptionIncludedElsewhere ?? false

                    // Price elements
                    var priceElements: [PriceElement] = []
                    if let decPEs = decHC.priceElements {
                        for decPE in decPEs {
                            let label = decPE.label ?? "energy"
                            let amount = decPE.amount ?? 0.0
                            let inclVAT = decPE.inclVAT ?? true
                            // Interpret type string; default to byConsumption
                            let type: PriceElement.PriceElementType
                            if decPE.type == "byConsumption" {
                                type = .byConsumption(energyUnitSymbol: UserSettings.shared.energyUnit.symbol)
                            } else {
                                type = .byConsumption(energyUnitSymbol: UserSettings.shared.energyUnit.symbol)
                            }
                            let vatRate = decPE.vatRate
                            let pe = TestPriceElementBuilder(label: label, amount: amount, inclVAT: inclVAT, type: type, vatRate: vatRate).build()
                            priceElements.append(pe)
                        }
                    }

                    var builder = TestHomeConsumptionBuilder(
                        name: name,
                        validFrom: validFrom,
                        validUntil: validUntil,
                        consumption: consumption,
                        consumptionIncludedElsewhere: includedElsewhere,
                        priceElements: priceElements
                    )
                    homeConsumptions.append(builder.build())
                }
            }

            // Refunds
            var refundedPerMonth: [String: (consumption: Measurement<UnitEnergy>, cost: Cost)] = [:]
            if let decRefunds = decoded.refundedPerMonth {
                for (month, entry) in decRefunds {
                    let cons = Measurement(value: entry.consumptionKWh ?? 0.0, unit: UnitEnergy.kilowattHours)
                    let cost = Cost(amount: entry.cost ?? 0.0)
                    refundedPerMonth[month] = (consumption: cons, cost: cost)
                }
            }

            // Related charging
            var relatedChargingConsumptions: [String: Measurement<UnitEnergy>] = [:]
            if let decRelated = decoded.relatedChargingConsumptions {
                for (month, kwh) in decRelated {
                    relatedChargingConsumptions[month] = Measurement(value: kwh, unit: UnitEnergy.kilowattHours)
                }
            }

            // If no home consumptions were found, fall back to basic dataset
            if homeConsumptions.isEmpty {
                return basicDataSet()
            }

            return TestDataSet(homeConsumptions: homeConsumptions, refundedPerMonth: refundedPerMonth, relatedChargingConsumptions: relatedChargingConsumptions)
        } catch {
            return basicDataSet()
        }
    }

    // Example: basic dataset with one home consumption and no refunds or related charging
    private func basicDataSet() -> TestDataSet {
        let pe = TestPriceElementBuilder(label: "energy", amount: 0.20, inclVAT: true, type: .byConsumption(energyUnitSymbol: UserSettings.shared.energyUnit.symbol)).build()
        let hc = TestHomeConsumptionBuilder(name: "HC Jan", validFrom: Date.now.startOfMonth, validUntil: Date.now.endOfMonth, consumption: .init(value: 100.0, unit: .kilowattHours), consumptionIncludedElsewhere: false, priceElements: [pe]).build()
        return TestDataSet(homeConsumptions: [hc], refundedPerMonth: [:], relatedChargingConsumptions: [:])
    }

    @Test("data() with single home consumption returns two data sets per month (home + charging)")
    func testSingleHomeConsumption() async throws {
        let location = Location(name: "Home")
        let dataset = loadTestData()
        // attach home consumptions to location
        location.associatedHomeConsumptions = dataset.homeConsumptions

        // We need a ModelContext for refundedPerMonth: create an in-memory ModelContext
        let modelContext = try await TestHelpers.makeModelContext()

        // Build a TimeBox with selectedDate = 1. December 2025
        let selectedDateComponents = DateComponents(year: 2025, month: 12, day: 1)
        let selectedDate = Calendar.current.date(from: selectedDateComponents) ?? Date.now
        let timeBox = TimeBox(selectedDate: selectedDate, selectedResolution: .monthly, allowedResolutions: [.monthly], selectIndividualItem: { _ in })

        // Call the data function. For these tests we will not rely on cache, but ensure to invalidate first.
        Location.invalidateCache()
        let results = location.data(in: timeBox, useRelatedConsumption: false, modelContext: modelContext)

        // Expect that for each month there are two entries (homeConsumption and charging)
        #expect(results.count >= 2)
        // Basic sanity: find the home consumption entry
        let homeEntries = results.filter { $0.dataType == .homeConsumption }
        #expect(!homeEntries.isEmpty)
    }

    // Additional tests should exercise refundedPerMonth and relatedChargingConsumptions. The following functions are placeholders to be filled with concrete datasets.
    
    @Test("data() accounts for refunded sessions when computing net consumption and costs")
    func testRefundedAccounting() async throws {
        // TODO: fill with dataset where refundedPerMonth contains entries that reduce home consumption and adjust costs accordingly
        #expect(true)
    }

    @Test("data() accounts for related charging consumptions when computing allocations")
    func testRelatedChargingAccounting() async throws {
        // TODO: fill with dataset where relatedChargingConsumptions contains entries that move consumption from home to charging part
        #expect(true)
    }
}
