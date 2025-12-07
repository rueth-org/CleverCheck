//
//  CarView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 24/11/2025.
//

import SwiftUI
import SwiftData

struct ChargerEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    let charger: Charger?
    
    @Query private var chargingLocations: [ChargingLocation]
    
    @State private var name: String = ""
    @State private var chargingLocation: ChargingLocation? = nil
    @State private var isArchived: Bool = false
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    private var editorTitle: String {
        charger == nil ? "New Charger" : "Edit Charger"
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $name)
            
            // Charging location
            Picker("Location", selection: $chargingLocation) {
                Text("- none -").tag(nil as ChargingLocation?)
                ForEach(chargingLocations, id: \.id) { location in
                    Text(location.name).tag(location)
                }
            }
            
            Toggle("Archived", isOn: $isArchived)
                .padding(.top)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(editorTitle)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    withAnimation {
                        saveAndExit()
                    }
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) {
                    cancelAndExit()
                }
            }
        }
        .onAppear {
            if let charger {
                // Edit the incoming charger.
                name = charger.name
                chargingLocation = charger.chargingLocation
                isArchived = charger.isArchived
            }
        }
        .alert(
            activeAlert?.title() ?? "Notice",
            isPresented: $showingAlert,
            presenting: activeAlert
        ) { activeAlert in
            activeAlert.button()
        } message: { activeAlert in
            activeAlert.message()
        }
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        let name = self.name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            activeAlert = .error(message: "Name is required.")
            showingAlert = true
        } else {
            if let charger {
                // Edit the location
                charger.name = name
                charger.chargingLocation = chargingLocation
                charger.isArchived = isArchived
            } else {
                let newCharger = Charger(name: name, chargingLocation: chargingLocation)
                newCharger.isArchived = isArchived
                modelContext.insert(newCharger)
            }
            
            // Leave editor
            navigationPath.removeLast()
        }
    }
}
