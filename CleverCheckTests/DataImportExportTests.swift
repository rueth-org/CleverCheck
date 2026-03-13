import Foundation
import SwiftData
import Testing
@testable import CleverCheck

@Suite("Data import/export")
struct DataImportExportTests {
    @Test("Import a representative subset of the backup JSON")
    @MainActor
    func testImportRepresentativeSubset() async throws {
        // Locate the test data JSON next to this test file
        let testFileURL = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("TestData.json")
        let raw = try Data(contentsOf: testFileURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(DataEncoder.Backup.self, from: raw)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        // Create an in-memory ModelContext (helper provided by test infra)
        let modelContainer = try TestHelpers.makeModelContainer()

        // Import
        let report = try DataImporter.importFrom(data: data, into: modelContainer.mainContext)

        // Basic expectations on the report
        #expect(report.cars == 2)
        #expect(report.chargers == 6)
        #expect(report.locations == 3)
        #expect(report.chargingCostPlans == 7)
        #expect(report.chargingSessions == 232)
        #expect(report.chargingSessionTemplates == 1)
        #expect(report.homeConsumptions == 46)
        #expect(report.priceElements == 149)
        #expect(report.errors.isEmpty)

        // Verify objects are present in the ModelContext
        let cars: [Car] = try modelContainer.mainContext.fetch(FetchDescriptor<Car>())
        let chargers: [Charger] = try modelContainer.mainContext.fetch(FetchDescriptor<Charger>())
        let locations: [Location] = try modelContainer.mainContext.fetch(FetchDescriptor<Location>())
        let plans: [ChargingCostPlan] = try modelContainer.mainContext.fetch(FetchDescriptor<ChargingCostPlan>())
        let sessions: [ChargingSession] = try modelContainer.mainContext.fetch(FetchDescriptor<ChargingSession>())
        let templates: [ChargingSessionTemplate] = try modelContainer.mainContext.fetch(FetchDescriptor<ChargingSessionTemplate>())
        let homes: [HomeConsumption] = try modelContainer.mainContext.fetch(FetchDescriptor<HomeConsumption>())
        let priceElements: [PriceElement] = try modelContainer.mainContext.fetch(FetchDescriptor<PriceElement>())

        #expect(cars.count >= 2)
        #expect(chargers.count >= 6)
        #expect(locations.count >= 3)
        #expect(plans.count >= 7)
        #expect(sessions.count >= 232)
        #expect(templates.count >= 1)
        #expect(homes.count >= 46)
        #expect(priceElements.count >= 149)

        // Re-importing the same data should not create duplicates (ids already present)
        let secondReport = try DataImporter.importFrom(data: data, into: modelContainer.mainContext)
        // Expect that nothing new was added (importer skips existing ids)
        #expect(secondReport.cars == 0)
        #expect(secondReport.chargers == 0)
        #expect(secondReport.locations == 0)
    }
}
