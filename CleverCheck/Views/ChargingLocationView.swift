//
//  CarView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 24/11/2025.
//

import SwiftUI

struct ChargingLocationView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    let chargingLocation: ChargingLocation?
    @State private var name: String = ""
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    private var editorTitle: String {
        chargingLocation == nil ? "New Location" : "Edit Location"
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $name)
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
            if let chargingLocation {
                // Edit the incoming chargingLocation.
                name = chargingLocation.name
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
            if let chargingLocation {
                // Edit the location
                chargingLocation.name = name
            } else {
                let newLocation = ChargingLocation(name: name)
                modelContext.insert(newLocation)
            }
            
            // Leave editor
            navigationPath.removeLast()
        }
    }
}
