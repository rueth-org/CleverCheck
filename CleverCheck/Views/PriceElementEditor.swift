//
//  PriceElementEditor.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 06/12/2025.
//

import SwiftUI

struct PriceElementEditor: View {
    @Binding var navigationPath: NavigationPath
    let priceElement: PriceElement?
    @Binding var priceElements: [PriceElement]
    let energyUnitSymbol: String
    
    @State private var label: String = ""
    @State private var amount: Cost = .init(amount: 0, currency: UserSettings.shared.currency)
    @State private var amountIsGross: Bool = true
    @State private var vatRate: Double = UserSettings.shared.vatRate
    @State private var elementType: PriceElement.PriceElementType = .byConsumption
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    private var isNewPriceElement: Bool {
        priceElement == nil
    }
    
    private var editorTitle: String {
        priceElement == nil ? "New Price Element" : "Edit Price Element"
    }
    
    private var priceElementTypes: [PriceElement.PriceElementType] {
        PriceElement.PriceElementType.allCases.map { $0 }
    }
    
    var body: some View {
        Form {
            HStack {
                Text("Label")
                TextField("Label", text: $label)
            }
            Picker("Type", selection: $elementType) {
                ForEach(priceElementTypes, id: \.self) { type in
                    Text(type.rawValue)
                }
            }
            HStack {
                Text("Cost amount")
                Spacer()
                TextField("Cost amount", value: $amount.amount, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("\(amount.currency.identifier)\(elementType.unitExtension(energyUnit: energyUnitSymbol))")
            }
            Toggle("Amount is gross", isOn: $amountIsGross)
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
                amount = priceElement.amount
                amountIsGross = priceElement.isGross
                elementType = priceElement.type
                vatRate = priceElement.vatRate
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
        let priceElementLabel = self.label.trimmingCharacters(in: .whitespaces)
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
        
        if isNewPriceElement {
            let newPriceElement = PriceElement(
                label: priceElementLabel,
                amount: amount,
                isGross: amountIsGross,
                type: elementType,
                vatRate: vatRate
            )
            
            priceElements.append(newPriceElement)
        } else {
            if let index = priceElements.firstIndex(of: priceElement!) {
                priceElements[index].label = priceElementLabel
                priceElements[index].amount = amount
                priceElements[index].isGross = amountIsGross
                priceElements[index].type = elementType
                priceElements[index].vatRate = vatRate
            } else {
                activeAlert = .fatalError(message: "Could not find the price element to edit.")
                showingAlert = true
                return
            }
        }
        
        // Leave editor
        navigationPath.removeLast()
    }
    
    
}
