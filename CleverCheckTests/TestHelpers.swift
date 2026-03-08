import Foundation
import SwiftData
@testable import CleverCheck

/// Helpers used by unit tests
enum TestHelpers {
    /// Create an in-memory ModelContext containing all app models for testing.
    /// This mirrors the models registered in the App's ModelContainer.
    @MainActor static func makeModelContainer() throws -> ModelContainer {
        // Use an in-memory model configuration for tests to avoid CloudKit/SwiftData background
        // registration collisions with the app's shared ModelContainer.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema([
            Car.self,
            Charger.self,
            ChargingCostPlan.self,
            ChargingSession.self,
            ChargingSessionTemplate.self,
            PriceElement.self,
            Location.self,
            HomeConsumption.self
        ])
        let container = try ModelContainer(for: schema, configurations: [config])
        // Disable autosave to avoid background persistence during tests
        container.mainContext.autosaveEnabled = false

        return container
    }
}

