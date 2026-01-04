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

    @Query private var priceElements: [PriceElement]
    
    @State private var showingChargingSessionPicker: Bool = false
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    @Query(sort: \Location.name) private var locations: [Location]
    
    private var editorTitle: String {
        isNew ? NSLocalizedString("New Home Consumption", comment: "") : NSLocalizedString("Edit Home Consumption", comment: "")
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
            Toggle("Consumption included elsewhere", isOn: $homeConsumption.consumptionIncludedElsewhere)
            Picker("Location", selection: $homeConsumption.associatedLocation) {
                Text("- none -").tag(nil as Location?)
                ForEach(locations, id: \.id) { location in
                    Text(location.name).tag(location as Location?)
                }
            }
            HStack {
                Text("Related charging sessions: \(homeConsumption.chargingSessions?.count ?? 0)")
                Spacer()
                Button(action: {
                    showingChargingSessionPicker = true
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.gray)
                }
            }
            .sheet(isPresented: $showingChargingSessionPicker) {
                ChargingSessionPicker(isShowing: $showingChargingSessionPicker, homeConsumption: homeConsumption)
            }
            TextField("Comments", text: $homeConsumption.comment, axis: .vertical)
                .lineLimit(3)
            
            Section(header: Text("Results")) {
                HStack {
                    Text("Price")
                    Spacer()
                    Text(homeConsumption.totalCost(isGross: UserSettings.shared.displayGrossPrices).formatted(.currency(code: UserSettings.shared.currencyIdentifier)))
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section(header: Text("Price Elements")) {
                // Add new price element
                Button("Add", systemImage: "plus.circle") {
                    save(andExit: false)
                    navigationPath.append(NavigationDestination.NewPriceElement(energyUnitSymbol: energyUnitSymbol))
                }
                
                // The existing price elements
                ForEach(priceElements, id: \.id) { priceElement in
                    NavigationLink(value: NavigationDestination.EditPriceElement(priceElement: priceElement, energyUnitSymbol: energyUnitSymbol)) {
                        HStack {
                            Text(priceElement.label)
                            Spacer()
                            Text(priceElement.amountDescription)
                            Text(priceElement.netGrossDescription)
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
                    homeConsumption: homeConsumption,
                    energyUnitSymbol: energyUnitSymbol
                )
            case .EditPriceElement(let priceElement, let energyUnitSymbol):
                PriceElementEditor(
                    navigationPath: $navigationPath,
                    priceElement: priceElement,
                    homeConsumption: homeConsumption,
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

    init(navigationPath: Binding<NavigationPath>, homeConsumption: HomeConsumption, isNew: Bool) {
        self._navigationPath = navigationPath
        self.homeConsumption = homeConsumption
        self.isNew = isNew
        
        let homeConsumptionID = homeConsumption.persistentModelID
        let predicate = #Predicate<PriceElement> { priceElement in
            priceElement.homeConsumption?.persistentModelID == homeConsumptionID
        }
        self._priceElements = Query(
            filter: predicate,
            sort: [SortDescriptor(\PriceElement.label)]
        )
    }
    
    private func deletePriceElements(at offsets: IndexSet) {
        for index in offsets {
            let priceElement = priceElements[index]
            withAnimation {
                modelContext.delete(priceElement)
            }
            try? modelContext.save()
        }
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func save(andExit: Bool) {
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
        if andExit {
            navigationPath.removeLast()
        }
    }
}
