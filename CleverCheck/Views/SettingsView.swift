//
//  SettingsView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/12/2025.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    
    @State private var showingAlert = false
    @State private var confirmDeletion = ""
    
    var body: some View {
        Text("Settings")
            .font(.headline)
            .padding()
        Form {
            Section(header: Text("Master Data")) {
                Button("Cars") {
                    navigationPath.append(ContentView.NavigationDestination.Cars)
                }
                Button("Charging Locations") {
                    navigationPath.append(ContentView.NavigationDestination.ChargingLocations)
                }
                Button("Chargers") {
                    navigationPath.append(ContentView.NavigationDestination.Chargers)
                }
                Button("Charging Cost Plans") {
                    navigationPath.append(ContentView.NavigationDestination.ChargingCostPlans)
                }
            }
            
            Section(header: Text("Danger Zone")) {
                Button("Delete all data") {
                    showingAlert = true
                }
                .foregroundColor(.red)
                .alert("DANGER", isPresented: $showingAlert) {
                    TextField("DELETE ALL", text: $confirmDeletion)
                    Button("OK", action: deleteAllData)
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Enter 'DELETE ALL' to confirm - this cannot be undone.")
                }
            }
        }
    }
    
    private func deleteAllData() {
        if confirmDeletion == "DELETE ALL" {
            modelContext.container.deleteAllData()
        }
    }
}
