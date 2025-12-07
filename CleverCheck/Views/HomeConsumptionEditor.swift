//
//  HomeConsumptionEditor.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 30/11/2025.
//

import SwiftUI
import SwiftData

struct HomeConsumptionEditor: View {
    enum NavigationDestination: Hashable {
        case NewPriceElement(energyUnitSymbol: String)
        case EditPriceElement(priceElement: PriceElement, energyUnitSymbol: String)
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @State var homeConsumption: HomeConsumption
    var isNew: Bool
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    @Query(sort: \ChargingLocation.name) private var chargingLocations: [ChargingLocation]
    
    private var editorTitle: String {
        isNew ? "New Home Consumption" : "Edit Home Consumption"
    }
    
    private var energyUnitSymbol: String {
        homeConsumption.consumption.unit.symbol
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $homeConsumption.name)
            DatePicker("Valid from", selection: $homeConsumption.validFrom, displayedComponents: .date)
            DatePicker("Valid until", selection: $homeConsumption.validUntil, displayedComponents: .date)
            HStack {
                Text("Consumption")
                TextField("", value: $homeConsumption.consumption.value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text(homeConsumption.consumption.unit.symbol)
            }
            Picker("Location", selection: $homeConsumption.associatedChargingLocation) {
                Text("- none -").tag(nil as ChargingLocation?)
                ForEach(chargingLocations, id: \.id) { location in
                    Text(location.name).tag(location as ChargingLocation?)
                }
            }
            
            Section(header: Text("Price Elements")) {
                // Add new price element
                Button("Add", systemImage: "plus.circle") {
                    navigationPath.append(NavigationDestination.NewPriceElement(energyUnitSymbol: energyUnitSymbol))
                }
                
                // The existing price elements
                ForEach(homeConsumption.priceElements, id: \.id) { priceElement in
                    NavigationLink(value: NavigationDestination.EditPriceElement(priceElement: priceElement, energyUnitSymbol: energyUnitSymbol)) {
                        HStack {
                            Text(priceElement.label)
                            Spacer()
                            Text(priceElement.description(homeConsumption: homeConsumption))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .onDelete(perform: deletePriceElements)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .NewPriceElement(let energyUnitSymbol):
                PriceElementEditor(
                    navigationPath: $navigationPath,
                    priceElement: nil,
                    priceElements: $homeConsumption.priceElements,
                    energyUnitSymbol: energyUnitSymbol
                )
            case .EditPriceElement(let priceElement, let energyUnitSymbol):
                PriceElementEditor(
                    navigationPath: $navigationPath,
                    priceElement: priceElement,
                    priceElements: $homeConsumption.priceElements,
                    energyUnitSymbol: energyUnitSymbol
                )
            }
        }
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
    
    private func deletePriceElements(at offsets: IndexSet) {
        // Delete it from the context
        withAnimation {
            homeConsumption.priceElements.remove(atOffsets: offsets)
        }
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        // Check for valid name
        let name = homeConsumption.name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            activeAlert = .error(message: "Name is required.")
            showingAlert = true
            return
        }
        
        // Check dates
        if homeConsumption.validFrom >= homeConsumption.validUntil {
            activeAlert = .error(message: "'Valid from' date must be before 'valid until' date.")
            showingAlert = true
            return
        }
        
        // Save if new
        if isNew {
            modelContext.insert(homeConsumption)
        }
        
        // Leave editor
        navigationPath.removeLast()
    }
}
