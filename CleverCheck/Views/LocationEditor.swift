//
//  CarView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 24/11/2025.
//

import SwiftUI

struct LocationEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    let location: Location?
    
    @State private var name: String = ""
    @State private var powerPriceServiceName: String? = nil
    @State private var powerPriceRegion: String? = nil
    @State private var isArchived: Bool = false
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?
    
    private var editorTitle: String {
        location == nil ? NSLocalizedString("New Location", comment: "") : NSLocalizedString("Edit Location", comment: "")
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $name)
            
            // Set power price service name
            Picker("Power Price Service", selection: $powerPriceServiceName) {
                Text("- none -").tag(nil as String?)
                // Use the provider's name as the identifier (String is Hashable). Using `\.self` fails
                // because `PowerPriceAPIProtocol` is a protocol existential and isn't Hashable/Identifiable.
                ForEach(EnergyDataService.shared.availableProviders, id: \.name) { service in
                    Text(service.name).tag(service.name as String?)
                }
            }
            
            // If the power price service is selected, show the region picker
            if let powerPriceServiceName {
                if let providerType = EnergyDataService.shared.findProviderType(named: powerPriceServiceName) {
                    // instantiate the provider type to read its instance property `regions`
                    Picker("Power Price Region", selection: $powerPriceRegion) {
                        Text("- none -").tag(nil as String?)
                        ForEach(providerType.init().regions, id: \.self) { region in
                            Text(region).tag(region as String)
                        }
                    }
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
            if let location {
                // Edit the incoming location.
                name = location.name
                powerPriceServiceName = location.powerPriceServiceName
                powerPriceRegion = location.powerPriceRegion
                isArchived = location.isArchived
            }
        }
        .alert(
            activeAlert?.title() ?? "Notice",
            isPresented: $showingAlert,
            presenting: activeAlert
        ) { activeAlert in
            activeAlert.actionButtons()
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
            activeAlert = SimpleAlert(type: .error(message: "Name is required."))
            showingAlert = true
        } else {
            if let location {
                // Edit the location
                location.name = name
                location.powerPriceServiceName = powerPriceServiceName
                location.powerPriceRegion = powerPriceRegion
                location.isArchived = isArchived
            } else {
                let newLocation = Location(name: name)
                newLocation.powerPriceServiceName = powerPriceServiceName
                newLocation.powerPriceRegion = powerPriceRegion
                newLocation.isArchived = isArchived
                modelContext.insert(newLocation)
            }
            
            // Save data and leave editor
            try? modelContext.save()
            navigationPath.removeLast()
        }
    }
}
