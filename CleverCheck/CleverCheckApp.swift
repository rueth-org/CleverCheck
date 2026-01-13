//
//  CleverCheckApp.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

@main
struct CleverCheckApp: App {
    var sharedModelContainer: ModelContainer = {
        do {
            let container = try ModelContainer(for:
                Car.self,
                Charger.self,
                ChargingCostPlan.self,
                ChargingSession.self,
                PriceElement.self,
                Location.self,
                HomeConsumption.self
            )
            // Turn off automatic implicit saves
            container.mainContext.autosaveEnabled = false
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
