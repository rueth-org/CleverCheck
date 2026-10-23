//
//  SeasonalPriceView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/10/2026.
//

import SwiftUI

struct SeasonalPriceEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    let seasonalPrice: SeasonalPrice?
    
    @State var name: String = ""
    @State var startDate: Date = Date()
    @State var endDate: Date = Date()
    @State var prices: Dictionary<Double, Cost> = [0.0: Cost(amount: 0.0)]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?
    
    @State private var editedTime: Double? = nil
    @State private var editingHour: Int? = nil
    @State private var editingMinute: Int? = nil
    
    private var isNewSeasonalPrice: Bool {
        seasonalPrice == nil
    }
    
    private var editorTitle: String {
        seasonalPrice == nil ? NSLocalizedString("New Seasonal Price", comment: "") : NSLocalizedString("Edit Seasonal Price", comment: "")
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $name)
            DatePicker("Start date", selection: $startDate, displayedComponents: .date)
            DatePicker("End date", selection: $endDate, displayedComponents: .date)
            
            List {
                ForEach(prices.keys.sorted(), id: \.self) { time in
                    let cost = prices[time]!
                    HStack {
                        if editedTime == time {
                            VStack {
                                Text("\(editingHour ?? 0, specifier: "%02d")")
                                Stepper("", value: Binding(
                                    get: { self.editingHour ?? 0 },
                                    set: { self.editingHour = $0 }
                                ), in: 0...23).labelsHidden()
                            }
                            Text(":")
                            VStack {
                                Text("\(editingMinute ?? 0, specifier: "%02d")")
                                Stepper("", value: Binding(
                                    get: { self.editingMinute ?? 0 },
                                    set: { self.editingMinute = $0 }
                                ), in: 0...45, step: 15).labelsHidden()
                            }
                            Spacer()
                            TextField("Cost", value: Binding(get: {
                                cost.amount
                            }, set: { newValue in
                                prices[time]?.amount = newValue
                            }), format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                            Button {
                                // Save the edited time and cost
                                let newTime = Double(editingHour ?? 0) + Double(editingMinute ?? 0) / 60.0
                                let newCost = prices[time]!
                                prices.removeValue(forKey: time)
                                prices[newTime] = newCost
                                editedTime = nil
                                editingHour = nil
                                editingMinute = nil
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                            Button {
                                // Cancel the edit
                                editedTime = nil
                                editingHour = nil
                                editingMinute = nil
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                        } else {
                            let hour = Int(time)
                            let minute = Int((time - Double(hour)) * 60)
                            Text("\(hour, specifier: "%02d"):\(minute, specifier: "%02d")")
                            Spacer()
                            Text(cost.formatted())
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editedTime = time
                            editingHour = Int(time)
                            editingMinute = Int((time - Double(editingHour ?? 0)) * 60)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }.tint(.blue)
                        
                        Button {
                            // Add a new price entry for this time
                            let newCost = Cost(amount: 0.0)
                            let newTime = time + 1 // Add one hour
                            prices[newTime] = newCost
                            
                            // Set edit mode
                            editedTime = newTime
                            editingHour = Int(newTime)
                            editingMinute = Int((newTime - Double(editingHour ?? 0)) * 60)
                        } label: {
                            Label("Add", systemImage: "plus")
                        }.tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        if canDelete(time) {
                            Button(role: .destructive) {
                                prices.removeValue(forKey: time)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } else {
                            Button(role: .destructive) {
                                // no action
                            } label: {
                                Label("Cannot delete", systemImage: "trash")
                            }
                            .tint(.secondary)
                            .disabled(true)
                        }
                    }
                }
                Text("24:00")
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
            if let seasonalPrice {
                // Edit the incoming seasonal price
                name = seasonalPrice.name
                startDate = seasonalPrice.startDate
                endDate = seasonalPrice.endDate
                prices = seasonalPrice.prices
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
        seasonalPrice: SeasonalPrice? = nil
    ) {
        self._navigationPath = navigationPath
        self.seasonalPrice = seasonalPrice
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            activeAlert = SimpleAlert(type: .error(message: "Please enter a name for the seasonal price."))
            showingAlert = true
            return
        }
        
        if isNewSeasonalPrice {
            let newSeasonalPrice = SeasonalPrice(
                name: name,
                startDate: startDate,
                endDate: endDate
            )
            
            newSeasonalPrice.prices = prices
            
            // Insert into database
            modelContext.insert(newSeasonalPrice)
        } else {
            if let seasonalPrice {
                seasonalPrice.name = name
                seasonalPrice.startDate = startDate
                seasonalPrice.endDate = endDate
                seasonalPrice.prices = prices
            } else {
                activeAlert = SimpleAlert(type: .fatalError(message: "Could not find the seasonal price to edit."))
                showingAlert = true
                return
            }
        }
        
        // Save data and leave editor
        try? modelContext.save()
        navigationPath.removeLast()
    }
    
    private func canDelete(_ time: Double) -> Bool {
        if prices.count == 1 {
            return false
        }
        
        // Check that time is not 0:00
        let hour = Int(time)
        let minute = Int((time - Double(hour)) * 60)
        if hour == 0 && minute == 0 {
            return false
        }
        
        return true
    }
}
