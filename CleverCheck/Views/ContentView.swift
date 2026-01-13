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
    }
}
