//
//  ContentView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?
        
    var body: some View {
        TabView {
            Tab("Charging", systemImage: "bolt.car") {
                ChargingView()
            }
            
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
        .task {
            do {
                // Initialize currencyConverterService
                try await UserSettings.shared.loadCurrencyConverterService()
            } catch {
                // Conversion failed, show warning and display original price
                activeAlert = SimpleAlert(type: .fatalError(message: "Could not load currency converter service. Costs will be shown in their original currency."))
                showingAlert = true
            }
        }
    }
}
