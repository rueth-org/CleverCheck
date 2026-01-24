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
        case NewPriceElement(homeConsumption: HomeConsumption, energyUnitSymbol: String)
        case EditPriceElement(homeConsumption: HomeConsumption, priceElement: PriceElement, energyUnitSymbol: String)
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @State private var homeConsumption: HomeConsumption?
    @State private var selectedLocation: Location?
    
    @State private var name: String = ""
    @State private var validFrom: Date = Date.now.startOfMonth
    @State private var validUntil: Date = Date.now.endOfMonth
    @State private var consumption: Measurement<UnitEnergy> = .init(value: 0.0, unit: .kilowattHours)
    @State private var consumptionIncludedElsewhere: Bool = false
    @State private var comment: String = ""

    @State private var showingChargingSessionPicker: Bool = false
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?
    
    @Query(sort: \Location.name) private var locations: [Location]
    
    private var editorTitle: String {
        homeConsumption == nil ? NSLocalizedString("New Home Consumption", comment: "") : NSLocalizedString("Edit Home Consumption", comment: "")
    }
    
    private var energyUnitSymbol: String {
        homeConsumption?.consumption.unit.symbol ?? UserSettings.shared.energyUnit.symbol
    }
    
    private var consumptionFromRelatedSessions: Measurement<UnitEnergy> {
        homeConsumption?.consumptionFromRelatedChargingSessions ?? .init(value: 0.0, unit: UserSettings.shared.energyUnit)
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $name)
            DatePicker("Valid from", selection: $validFrom, displayedComponents: .date)
            DatePicker("Valid until", selection: $validUntil, displayedComponents: .date)
            Picker("Location", selection: $selectedLocation) {
                Text("- none -").tag(nil as Location?)
                ForEach(locations, id: \.id) { location in
                    Text(location.name).tag(location as Location?)
                }
            }
            HStack {
                Text("Consumption")
                TextField("", value: $consumption.value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text(consumption.unit.symbol)
            }
            Toggle("Consumption included elsewhere", isOn: $consumptionIncludedElsewhere)
            
            HStack {
                Text("\(homeConsumption?.chargingSessions?.count ?? 0) related charging sessions: \(consumptionFromRelatedSessions.formatted())")
                Spacer()
                if homeConsumption != nil {
                    Button(action: {
                        showingChargingSessionPicker = true
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.gray)
                    }
                }
            }
            TextField("Comments", text: $comment, axis: .vertical)
                .lineLimit(3)
            
            Section(header: Text("Results")) {
                HStack {
                    Text("Gross Cost")
                    Spacer()
                    Text(homeConsumption?.totalCost(isGross: UserSettings.shared.displayGrossPrices).gross.formatted(.currency(code: UserSettings.shared.currencyIdentifier)) ?? "-")
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Net Cost")
                    Spacer()
                    Text(homeConsumption?.totalCost(isGross: UserSettings.shared.displayGrossPrices).net.formatted(.currency(code: UserSettings.shared.currencyIdentifier)) ?? "-")
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section(header: Text("Price Elements")) {
                if let homeConsumption {
                    // Add new price element
                    Button("Add", systemImage: "plus.circle") {
                        navigationPath.append(NavigationDestination.NewPriceElement(homeConsumption: homeConsumption, energyUnitSymbol: energyUnitSymbol))
                    }
                } else {
                    Text("Please save your changes before adding price elements.")
                        .italic()
                    Button("Save now", systemImage: "checkmark.circle") {
                        withAnimation {
                            save(andExit: false)
                        }
                    }
                }
                
                // The existing price elements
                if let homeConsumption {
                    ForEach(homeConsumption.priceElements ?? [], id: \.id) { priceElement in
                        NavigationLink(value: NavigationDestination.EditPriceElement(
                            homeConsumption: homeConsumption,
                            priceElement: priceElement,
                            energyUnitSymbol: energyUnitSymbol
                        )) {
                            HStack {
                                Text(priceElement.label)
                                Spacer()
                                Text(priceElement.amountDescription)
                                Text(priceElement.netGrossDescription)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(for: priceElement)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            
            if let homeConsumption {
                Button("Delete home consumption", systemImage: "trash", role: .destructive) {
                    activeAlert = SimpleAlert(
                        type: .warning(message: "This will delete the home consumption including all related price elements. Are you sure?"),
                        customButtons: [
                            SimpleAlertButton(title: NSLocalizedString("Cancel", comment: ""), role: .cancel) { },
                            SimpleAlertButton(title: NSLocalizedString("Delete", comment: ""), role: .destructive) {
                                delete(homeConsumption)
                            }
                        ]
                    )
                    showingAlert = true
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(editorTitle)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    withAnimation {
                        save(andExit: true)
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
                self.name = homeConsumption.name
                self.validFrom = homeConsumption.validFrom
                self.validUntil = homeConsumption.validUntil
                self.consumption = homeConsumption.consumption
                self.consumptionIncludedElsewhere = homeConsumption.consumptionIncludedElsewhere
                self.selectedLocation = homeConsumption.associatedLocation
                self.comment = homeConsumption.comment
            }
        }
        .sheet(isPresented: $showingChargingSessionPicker) {
            if let homeConsumption {
                ChargingSessionPicker(isShowing: $showingChargingSessionPicker, homeConsumption: homeConsumption)
            } else {
                Text("Please save your changes before selecting a charging session.")
                    .italic()
                    .padding()
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

    init(
        navigationPath: Binding<NavigationPath>,
        homeConsumption: HomeConsumption? = nil,
        selectedLocation: Location? = nil
    ) {
        self._navigationPath = navigationPath
        self._homeConsumption = State(initialValue: homeConsumption)
        self._selectedLocation = State(initialValue: selectedLocation)
    }
    
    private func delete(for priceElement: PriceElement) {
        // Delete it from the context
        withAnimation {
            modelContext.delete(priceElement)
        }
        try? modelContext.save()
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func save(andExit: Bool) {
        // Check for valid name
        let name = self.name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            activeAlert = SimpleAlert(type: .error(message: "Name is required."))
            showingAlert = true
            return
        }
        
        // Check dates
        if self.validFrom >= self.validUntil {
            activeAlert = SimpleAlert(type: .error(message: "'Valid from' date must be before 'valid until' date."))
            showingAlert = true
            return
        }
        
        if let homeConsumption {
            // Updating an existing home consumption
            homeConsumption.name = name
            homeConsumption.validFrom = self.validFrom.startOfDay
            homeConsumption.validUntil = self.validUntil.endOfDay
            homeConsumption.consumption = self.consumption
            homeConsumption.consumptionIncludedElsewhere = self.consumptionIncludedElsewhere
            homeConsumption.associatedLocation = self.selectedLocation
            homeConsumption.comment = self.comment
        } else {
            // Create new home consumption
            let newHomeConsumption = HomeConsumption(
                name: name,
                validFrom: self.validFrom.startOfDay,
                validUntil: self.validUntil.endOfDay,
                consumption: self.consumption,
                consumptionIncludedElsewhere: self.consumptionIncludedElsewhere
            )
            newHomeConsumption.associatedLocation = self.selectedLocation
            newHomeConsumption.comment = self.comment
            
            // Insert into model
            modelContext.insert(newHomeConsumption)
            
            // Update state variable
            self.homeConsumption = newHomeConsumption
        }
        
        // Save data
        try? modelContext.save()
        
        // Leave editor
        if andExit {
            navigationPath.removeLast()
        }
    }
    
    private func delete(_ homeConsumption: HomeConsumption) {
        navigationPath.removeLast()
        modelContext.delete(homeConsumption)
        try? modelContext.save()
    }
}
