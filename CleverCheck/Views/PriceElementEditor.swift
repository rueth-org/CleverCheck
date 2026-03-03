//
//  PriceElementEditor.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 06/12/2025.
//

import SwiftUI
import SwiftData

struct PriceElementEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    let priceElement: PriceElement?
    let homeConsumption: HomeConsumption
    let energyUnitSymbol: String
    
    @Query private var priceElements: [PriceElement]
    
    @State private var label: String = ""
    @State private var amount: Cost = .init(amount: 0)
    @State private var includesVAT: Bool = true
    @State private var vatRate: Double = UserSettings.shared.vatRate
    @State private var elementType: PriceElement.PriceElementType = .byConsumption(energyUnitSymbol: UserSettings.shared.energyUnit.symbol)
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?
    
    private var isNewPriceElement: Bool {
        priceElement == nil
    }
    
    private var editorTitle: String {
        priceElement == nil ? NSLocalizedString("New Price Element", comment: "") : NSLocalizedString("Edit Price Element", comment: "")
    }
    
    var body: some View {
        Form {
            HStack {
                Text("Label")
                TextField("Label", text: $label)
            }
            Picker("Type", selection: $elementType) {
                ForEach(PriceElement.PriceElementType.allCases, id: \.self) { type in
                    Text(type.description).tag(type)
                }
            }
            HStack {
                Text("Cost amount")
                Button(action: {
                    amount.amount = -amount.amount
                }) {
                    Text("+/-")
                }
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)
                Spacer()
                TextField("Cost amount", value: $amount.amount, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("\(amount.currency)\(elementType.unitExtension)")
            }
            Toggle("Amount is gross", isOn: $includesVAT)
            HStack {
                Text("VAT Rate")
                TextField("VAT Rate", value: $vatRate, format: .percent)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(editorTitle)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveAndExit()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) {
                    cancelAndExit()
                }
            }
        }
        .onAppear {
            if let priceElement {
                // Edit the incoming price element
                label = priceElement.label
                amount = priceElement.converted
                includesVAT = priceElement.isGross
                elementType = priceElement.type
                vatRate = priceElement.vatRate
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
        priceElement: PriceElement? = nil,
        homeConsumption: HomeConsumption,
        energyUnitSymbol: String
    ) {
        self._navigationPath = navigationPath
        self.priceElement = priceElement
        self.homeConsumption = homeConsumption
        self.energyUnitSymbol = energyUnitSymbol
        
        let homeConsumptionID = homeConsumption.id
        let predicate: Predicate<PriceElement> = #Predicate {
            $0.homeConsumption?.id == homeConsumptionID
        }
        self._priceElements = Query(
            filter: predicate,
            sort: [SortDescriptor(\PriceElement.label)]
        )
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        let priceElementLabel = self.label.trimmingCharacters(in: .whitespaces)
        if priceElementLabel.isEmpty {
            activeAlert = SimpleAlert(type: .error(message: "Label of the price element cannot be empty."))
            showingAlert = true
            return
        }
        
        if priceElements.count(where: { $0.label == priceElementLabel }) > (isNewPriceElement ? 0 : 1) {
            activeAlert = SimpleAlert(type: .error(message: "Label of the price element already exists."))
            showingAlert = true
            return
        }
        
        if isNewPriceElement {
            let newPriceElement = PriceElement(
                label: priceElementLabel,
                amount: amount,
                inclVAT: includesVAT,
                type: elementType,
                vatRate: vatRate
            )
            
            // Relate to home consumption
            newPriceElement.homeConsumption = homeConsumption
            
            // Insert into database
            modelContext.insert(newPriceElement)
        } else {
            if let index = priceElements.firstIndex(of: priceElement!) {
                priceElements[index].label = priceElementLabel
                priceElements[index].amount = amount
                priceElements[index].isGross = includesVAT
                priceElements[index].type = elementType
                priceElements[index].vatRate = vatRate
            } else {
                activeAlert = SimpleAlert(type: .fatalError(message: "Could not find the price element to edit."))
                showingAlert = true
                return
            }
        }
        
        // Save data and leave editor
        try? modelContext.save()
        navigationPath.removeLast()
    }
    
    
}
