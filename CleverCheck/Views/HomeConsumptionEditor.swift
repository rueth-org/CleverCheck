//
//  HomeConsumptionEditor.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 30/11/2025.
//

import SwiftUI

struct HomeConsumptionEditor: View {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private enum Field: Int, Hashable {
        case newPriceElement, editedPriceElement
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    var homeConsumption: HomeConsumption?
    
    @State private var name: String = ""
    @State private var validFrom: Date = Date.now.startDateOfMonth
    @State private var validUntil: Date = Date.now.endDateOfMonth
    @State private var consumption: Measurement<UnitEnergy> = .init(value: 0, unit: .kilowattHours)
    @State private var associatedChargingLocation: ChargingLocation?
    @State private var priceElements: [PriceElement] = []
    
    @State private var editedPriceElementID: UUID?
    @State private var enteringNewPriceElement: Bool = false
    @State private var priceElementLabel: String = ""
    @State private var priceElementAmount: Cost = .init(amount: 0, currency: UserSettings.settings.currency)
    @State private var priceElementType: PriceElement.PriceElementType = .byConsumption
    
    private var isNewPriceElement: Bool {
        editedPriceElementID == nil
    }
    
    @FocusState private var focusedField: Field?
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    private var editorTitle: String {
        homeConsumption == nil ? "New Home Consumption" : "Edit Home Consumption"
    }
    
    private var priceElementTypes: [PriceElement.PriceElementType] {
        PriceElement.PriceElementType.allCases.map { $0 }
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
            
            Section(header: Text("Price Elements")) {
                // Add new price element
                if enteringNewPriceElement {
                    editPriceElementView()
                } else {
                    Button("Add", systemImage: "plus.circle") {
                        // Check if currently editing another price element
                        if editedPriceElementID != nil {
                            // Save the edited price element
                            self.addPriceElement()
                        }
                        
                        withAnimation {
                            // Show the new price element fields
                            self.enteringNewPriceElement = true
                            self.focusedField = .newPriceElement
                        }
                    }
                }
                
                ForEach(priceElements, id: \.id) { priceElement in
                    if editedPriceElementID != nil && editedPriceElementID! == priceElement.id {
                        // Editing an existing price element
                        editPriceElementView()
                    } else {
                        // Displaying an existing price element
                        HStack {
                            Text(priceElement.label)
                            Spacer()
                            Text(priceElement.description(homeConsumption: homeConsumption))
                                .multilineTextAlignment(.trailing)
                        }
                        .swipeActions(edge: .trailing) {
                            // The edit button
                            Button("Edit", systemImage: "pencil") {
                                // Check if currently adding a new price element
                                if enteringNewPriceElement {
                                    // Save the new price element first
                                    self.addPriceElement()
                                }
                                
                                // Prepare for editing
                                selectPriceElement(priceElement)
                            }
                            .tint(.blue)
                            
                            // The delete button
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                withAnimation {
                                    // First clear edit fields if filled
                                    if self.enteringNewPriceElement {
                                        deselectPriceElement()
                                    }
                                    
                                    // Then delete typical amount
                                    deletePriceElement(element: priceElement)
                                }
                            }
                            .tint(.red)
                        }
                    }
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
    
    private func selectPriceElement(_ priceElement: PriceElement) {
        self.priceElementLabel = priceElement.label
        self.priceElementAmount = priceElement.amount
        self.priceElementType = priceElement.type
        withAnimation {
            self.editedPriceElementID = priceElement.id
            self.focusedField = .editedPriceElement
        }
    }
    
    private func deselectPriceElement() {
        self.priceElementLabel = ""
        self.priceElementAmount = .init(amount: 0, currency: UserSettings.settings.currency)
        self.priceElementType = .byConsumption
        withAnimation {
            self.editedPriceElementID = nil
            self.enteringNewPriceElement = false
            self.focusedField = nil
        }
    }
    
    private func addPriceElement() {
        let priceElementLabel = self.priceElementLabel.trimmingCharacters(in: .whitespaces)
        if priceElementLabel.isEmpty {
            activeAlert = .error(message: "Label of the price element cannot be empty.")
            showingAlert = true
            return
        }
        
        if priceElements.count(where: { $0.label == priceElementLabel }) > (isNewPriceElement ? 0 : 1) {
            activeAlert = .error(message: "Label of the price element already exists.")
            showingAlert = true
            return
        }
        
        let newPriceElement = PriceElement(
            label: priceElementLabel,
            amount: priceElementAmount,
            type: priceElementType
        )
        
        if isNewPriceElement {
            priceElements.append(newPriceElement)
        } else {
            if let index = priceElements.firstIndex(where: { $0.id == editedPriceElementID! }) {
                priceElements[index] = newPriceElement  
            } else {
                activeAlert = .fatalError(message: "Cannot find price element to edit.")
                showingAlert = true
                return
            }
        }
        
        // Reset input fields
        deselectPriceElement()
    }
    
    private func deletePriceElement(element: PriceElement) {
        if let index = priceElements.firstIndex(of: element) {
            priceElements.remove(at: index)
        }
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        // Make sure everything is saved
        if enteringNewPriceElement || editedPriceElementID != nil {
            addPriceElement()
        }
        
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
            // Edit the location
            homeConsumption.name = name
            homeConsumption.validFrom = validFrom
            homeConsumption.validUntil = validUntil
            homeConsumption.consumption = consumption
            homeConsumption.priceElements = priceElements
        } else {
            let newHomeConsumption = HomeConsumption(name: name, validFrom: validFrom, validUntil: validUntil, consumption: consumption)
            modelContext.insert(newHomeConsumption)
        }
        
        // Leave editor
        navigationPath.removeLast()
    }
    
    @ViewBuilder
    func editPriceElementView() -> some View {
        VStack {
            HStack {
                TextField("Label", text: $priceElementLabel)
                    .focused($focusedField, equals: .newPriceElement)
                    .onSubmit {
                        self.addPriceElement()
                    }
                    .submitLabel(.done)
                TextField("Amount", value: $priceElementAmount.amount, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .onSubmit {
                        self.addPriceElement()
                    }
                    .submitLabel(.done)
                Text("\(priceElementAmount.currency.identifier)\(priceElementType.unitExtension(energyUnit: homeConsumption?.consumption.unit.symbol ?? UserSettings.settings.energyUnit.symbol))")
                Button {
                    self.addPriceElement()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
            Picker("Type", selection: $priceElementType) {
                ForEach(priceElementTypes, id: \.self) { type in
                    Text(type.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
