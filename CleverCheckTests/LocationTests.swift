// swift
import Testing
import Foundation
@testable import CleverCheck
import SwiftData

@Suite("Location data aggregation")
struct LocationTests {
    @Test("data() with several sets of home consumptions", arguments: [
        ("Irisvej 33", 2025, 10,
         totalConsumptionKWh: 767,
         totalCost: Cost(amount: 1575.65),
         refundedConsumptionKWh: 139.1,
         refundedCost: Cost(amount: 258.73),
         chargingConsumptionKWh: 299.65,
         chargingCost: Cost(amount: 399.28),
         homeConsumptionKWh: 328.25,
         homeCost: Cost(amount: 688.45)
        ),
        ("Irisvej 33", 2025, 11,
         totalConsumptionKWh: 1071.0,
         totalCost: Cost(amount: 2416.91),
         refundedConsumptionKWh: 374.5,
         refundedCost: Cost(amount: 726.53),
         chargingConsumptionKWh: 260.61,
         chargingCost: Cost(amount: 438.27),
         homeConsumptionKWh: 435.89,
         homeCost: Cost(amount: 1057.93)
        ),
        ("Irisvej 33", 2025, 12,
         totalConsumptionKWh: 1008.0,
         totalCost: Cost(amount: 2147.47),
         refundedConsumptionKWh: 342.9,
         refundedCost: Cost(amount: 648.08),
         chargingConsumptionKWh: 208.43,
         chargingCost: Cost(amount: 283.34),
         homeConsumptionKWh: 456.67,
         homeCost: Cost(amount: 1029.51)
        ),
        ("Irisvej 33", 2026, 1,
         totalConsumptionKWh: 1406.521,
         totalCost: Cost(amount: 1910.37),
         refundedConsumptionKWh: 506.4,
         refundedCost: Cost(amount: 582.36),
         chargingConsumptionKWh: 284.4,
         chargingCost: Cost(amount: 419.60),
         homeConsumptionKWh: 615.721,
         homeCost: Cost(amount: 908.42)
        )
    ])
    func testSingleHomeConsumption(
        _ locationName: String,
        _ year: Int,
        _ month: Int,
        totalConsumptionKWh: Double,
        totalCost: Cost,
        refundedConsumptionKWh: Double,
        refundedCost: Cost,
        chargingConsumptionKWh: Double,
        chargingCost: Cost,
        homeConsumptionKWh: Double,
        homeCost: Cost
    ) async throws {
        // Create in-memory database
        let modelContainer = try await TestHelpers.makeModelContainer()
        
        // Locate the test data JSON next to this test file
        let testFileURL = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("TestData.json")
        
        // Load test data into the in-memory database
        let report = try await DataImporter.importFromFile(url: testFileURL, into: modelContainer.mainContext)
        #expect(report.errors.isEmpty, "Data import should not have errors, but found: \(report.errors)")
        
        // Find the location by name
        guard let existingLocations: [Location] = await (try? modelContainer.mainContext.fetch(FetchDescriptor<Location>())) else {
            #expect(Bool(false), "Failed to fetch locations from model context")
            return
        }
        
        guard let location = existingLocations.first(where: { $0.name == locationName }) else {
            #expect(Bool(false), "Failed to find location with name \(locationName) in model context")
            return
        }
        
        // Build a TimeBox with selectedDate from the function arguments and monthly resolution
        let selectedDateComponents = DateComponents(year: year, month: month, day: 1)
        let selectedDate = Calendar.current.date(from: selectedDateComponents) ?? Date.now
        let timeBox = TimeBox(selectedDate: selectedDate, selectedResolution: .monthly, allowedResolutions: [.monthly], selectIndividualItem: { _ in })

        // Call the data function. For these tests we will not rely on cache, but ensure to invalidate first.
        Location.invalidateCache()
        let data = await location.data(in: timeBox, useRelatedConsumption: true, modelContext: modelContainer.mainContext)
        
        let analysis = HomeConsumptionWaterfallChart(timeBox: timeBox, data: data, chartType: .consumption)
        let totalData = await analysis.totalData
        let homeData = await analysis.homeData
        let chargingData = await analysis.chargingData
        let refundedData = await analysis.chargingRefundedData
        
        // Verify total data
        let calculatedTotalConsumptionKWh = totalData.consumption.converted(to: .kilowattHours).value
        #expect(
            approxEqual(calculatedTotalConsumptionKWh, totalConsumptionKWh, relTol: 1e-3),
            "Expected total consumption \(totalConsumptionKWh) kWh, but got \(calculatedTotalConsumptionKWh) kWh"
        )
        #expect(
            totalData.cost.isApproximatelyEqual(to: totalCost, relTol: 1e-3),
            "Expected total cost \(totalCost), but got \(totalData.cost)"
        )
        
        // Verify home data
        let calculatedHomeConsumptionKWh = homeData.consumption.converted(to: .kilowattHours).value
        #expect(
            approxEqual(calculatedHomeConsumptionKWh, homeConsumptionKWh, relTol: 1e-3),
            "Expected home consumption \(homeConsumptionKWh) kWh, but got \(calculatedHomeConsumptionKWh) kWh"
        )
        #expect(
            homeData.cost.isApproximatelyEqual(to: homeCost, relTol: 1e-3),
            "Expected home cost \(homeCost), but got \(homeData.cost)"
        )
        
        // Verify charging data
        let calculatedChargingConsumptionKWh = chargingData.consumption.converted(to: .kilowattHours).value
        #expect(
            approxEqual(calculatedChargingConsumptionKWh, chargingConsumptionKWh, relTol: 1e-3),
            "Expected charging consumption \(chargingConsumptionKWh) kWh, but got \(calculatedChargingConsumptionKWh) kWh"
        )
        #expect(
            chargingData.cost.isApproximatelyEqual(to: chargingCost, relTol: 1e-3),
            "Expected charging cost \(chargingCost), but got \(chargingData.cost)"
        )
        
        // Verify refunded data
        let calculatedRefundedConsumptionKWh = refundedData.consumption.converted(to: .kilowattHours).value
        #expect(
            approxEqual(calculatedRefundedConsumptionKWh, refundedConsumptionKWh, relTol: 1e-3),
            "Expected refunded consumption \(refundedConsumptionKWh) kWh, but got \(calculatedRefundedConsumptionKWh) kWh"
        )
        #expect(
            refundedData.cost.isApproximatelyEqual(to: refundedCost, relTol: 1e-3),
            "Expected charging cost \(refundedCost), but got \(refundedData.cost)"
        )
    }
}

func approxEqual(_ a: Double, _ b: Double, relTol: Double = 1e-3, absTol: Double = 1e-6) -> Bool {
    let diff = abs(a - b)
    if diff <= absTol { return true }
    return diff <= relTol * max(abs(a), abs(b), 1.0)
}

extension Cost {
    func isApproximatelyEqual(to other: Cost, relTol: Double = 1e-3, absTol: Double = 1e-6) -> Bool {
        approxEqual(self.amount, other.amount, relTol: relTol, absTol: absTol)
    }
}
