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
    var homeConsumption: HomeConsumption?
    
    @State private var name: String = ""
    @State private var validFrom: Date = Date.now.startDateOfMonth
    @State private var validUntil: Date = Date.now.endDateOfMonth
    @State private var consumption: Measurement<UnitEnergy> = .init(value: 0, unit: .kilowattHours)
    @State private var associatedChargingLocation: ChargingLocation?
    @State private var priceElements: [PriceElement] = []
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    @Query(sort: \ChargingLocation.name) private var chargingLocations: [ChargingLocation]
    
    private var editorTitle: String {
        homeConsumption == nil ? "New Home Consumption" : "Edit Home Consumption"
    }
    
    private var energyUnitSymbol: String {
        homeConsumption?.consumption.unit.symbol ?? UserSettings.shared.energyUnit.symbol
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $name)
            DatePicker("Valid from", selection: $validFrom, displayedComponents: .date)
            DatePicker("Valid until", selection: $validUntil, displayedComponents: .date)
            HStack {
                Text("Consumption")
                TextField("", value: $consumption.value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text(consumption.unit.symbol)
            }
            Picker("Location", selection: $associatedChargingLocation) {
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
                ForEach(priceElements, id: \.id) { priceElement in
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
                    priceElements: $priceElements,
                    energyUnitSymbol: energyUnitSymbol
                )
            case .EditPriceElement(let priceElement, let energyUnitSymbol):
                PriceElementEditor(
                    navigationPath: $navigationPath,
                    priceElement: priceElement,
                    priceElements: $priceElements,
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
        .onAppear {
            if let homeConsumption {
                // Edit the incoming homeConsumption.
                name = homeConsumption.name
                validFrom = homeConsumption.validFrom
                validUntil = homeConsumption.validUntil
                consumption = homeConsumption.consumption
                associatedChargingLocation = homeConsumption.associatedChargingLocation
                priceElements = homeConsumption.priceElements
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
        // TODO check if can be deleted
        for offset in offsets {
            // Find location in our query
            let priceElement = priceElements[offset]

            // Delete it from the context
            withAnimation {
                modelContext.delete(priceElement)
            }
        }
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        // Check for valid name
        let name = self.name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            activeAlert = .error(message: "Name is required.")
            showingAlert = true
            return
        }
        
        // Check dates
        if validFrom >= validUntil {
            activeAlert = .error(message: "'Valid from' date must be before 'valid until' date.")
            showingAlert = true
            return
        }
        
        // Update or create homeConsumption
        if let homeConsumption {
            // Edit the home consumption
            homeConsumption.name = name
            homeConsumption.validFrom = validFrom
            homeConsumption.validUntil = validUntil
            homeConsumption.consumption = consumption
            homeConsumption.associatedChargingLocation = associatedChargingLocation
        } else {
            let newHomeConsumption = HomeConsumption(
                name: name,
                validFrom: validFrom,
                validUntil: validUntil,
                consumption: consumption,
                associatedChargingLocation: associatedChargingLocation
            )
            for priceElement in priceElements {
                newHomeConsumption.priceElements.append(priceElement)
            }
            modelContext.insert(newHomeConsumption)
        }
        
        // Leave editor
        navigationPath.removeLast()
    }
}
