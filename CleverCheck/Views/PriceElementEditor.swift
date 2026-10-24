//
//  PriceElementEditor.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 06/12/2025.
//

import SwiftUI
import SwiftData

struct PriceElementEditor: View {
    enum NavigationDestination: Hashable {
        case SelectSeasonalPrice
    }

    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    let priceElement: PriceElement?
    let homeConsumption: HomeConsumption
    let energyUnitSymbol: String
    
    @Query private var priceElements: [PriceElement]
    @Query private var seasonalPrices: [SeasonalPrice]
    
    @State private var label: String = ""
    @State private var amount: Cost = .init(amount: 0)
    @State private var includesVAT: Bool = true
    @State private var isSeasonal: Bool = false
    @State private var seasonalPrice: SeasonalPrice? = nil
    @State private var vatRate: Double = UserSettings.shared.vatRate
    @State private var elementType: PriceElement.PriceElementType = .byConsumption(energyUnitSymbol: UserSettings.shared.energyUnit.symbol)
    @State private var excludeFromSimulation: Bool = false
    
    @State private var selectedSeasonalPrice: SeasonalPrice? = nil
    
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
            // The label of the price element
            HStack {
                Text("Label")
                TextField("Label", text: $label)
            }
            
            // Price element type
            Picker("Type", selection: $elementType) {
                ForEach(PriceElement.PriceElementType.allCases, id: \.self) { type in
                    Text(type.description).tag(type)
                }
            }
            
            // Cost
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
            
            // Whether the amount includes VAT
            Toggle("Amount is gross", isOn: $includesVAT)
            
            // VAT rate
            HStack {
                Text("VAT Rate")
                TextField("VAT Rate", value: $vatRate, format: .percent)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            
            // Whether the amount is seasonal
            Toggle("Amount is seasonal", isOn: $isSeasonal)
                .onChange(of: isSeasonal) { oldValue, newValue in
                    // We set the selectedSeasonalPrice to the seasonalPrice if not set
                    if newValue && selectedSeasonalPrice == nil {
                        selectedSeasonalPrice = seasonalPrice
                    }
                }
            if isSeasonal {
                NavigationLink(value: NavigationDestination.SelectSeasonalPrice) {
                    if let selectedSeasonalPrice {
                        VStack(alignment: .leading) {
                            Text("\(selectedSeasonalPrice.name)")
                            Text("\(selectedSeasonalPrice.startDate, format: UserSettings.shared.displayDateFormat) - \(selectedSeasonalPrice.endDate, format: UserSettings.shared.displayDateFormat)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Select seasonal price")
                    }
                }
            }
            
            // Whether to exclude the price element from simulations
            Toggle("Exclude from simulation", isOn: $excludeFromSimulation)
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .SelectSeasonalPrice:
                SeasonalPricesView(navigationPath: $navigationPath, selectedSeasonalPrice: $selectedSeasonalPrice)
            }
        }
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
                isSeasonal = priceElement.seasonalPrice != nil || selectedSeasonalPrice != nil
                seasonalPrice = priceElement.seasonalPrice
                excludeFromSimulation = priceElement.excludeFromSimulation
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
        
        if isSeasonal && selectedSeasonalPrice == nil {
            activeAlert = SimpleAlert(type: .error(message: "Please select a seasonal price."))
            showingAlert = true
            return
        }
        
        if isNewPriceElement {
            let newPriceElement = PriceElement(
                label: priceElementLabel,
                amount: amount,
                inclVAT: includesVAT,
                type: elementType,
                vatRate: vatRate,
                excludeFromSimulation: excludeFromSimulation
            )
            
            // Relate to seasonal price
            newPriceElement.seasonalPrice = isSeasonal ? selectedSeasonalPrice : nil
            
            // Relate to home consumption
            newPriceElement.homeConsumption = homeConsumption
            
            // Insert into database
            modelContext.insert(newPriceElement)
        } else {
            if let index = priceElements.firstIndex(of: priceElement!) {
                priceElements[index].label = priceElementLabel
                priceElements[index].amount = amount
                priceElements[index].isGross = includesVAT
                priceElements[index].seasonalPrice = isSeasonal ? selectedSeasonalPrice : nil
                priceElements[index].type = elementType
                priceElements[index].vatRate = vatRate
                priceElements[index].excludeFromSimulation = excludeFromSimulation
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
