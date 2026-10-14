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
    let parentPriceElement: PriceElement
    let seasonalPrice: SeasonalPrice?
    
    @State var startDate: Date = Date()
    @State var endDate: Date = Date()
    @State var prices: Dictionary<Double, Cost> = [:]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?
    
    @State private var editedTime: Double? = nil
    
    private var isNewSeasonalPrice: Bool {
        seasonalPrice == nil
    }
    
    private var editorTitle: String {
        seasonalPrice == nil ? NSLocalizedString("New Seasonal Price", comment: "") : NSLocalizedString("Edit Seasonal Price", comment: "")
    }
    
    var body: some View {
        Form {
            DatePicker("Start date", selection: $startDate, displayedComponents: .date)
            DatePicker("End date", selection: $endDate, displayedComponents: .date)
            
            List {
                ForEach(prices.keys.sorted(), id: \.self) { time in
                    let cost = prices[time]!
                    var hour = Int(time)
                    var minute = Int((time - Double(hour)) * 60)
                    HStack {
                        if editedTime == time {
                            VStack {
                                Button {
                                    hour += 1
                                    if hour == 23 {
                                        hour = 23
                                    }
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                
                                Text("\(hour, specifier: "%02d")")
                                
                                Button {
                                    hour -= 1
                                    if hour == 0 {
                                        hour = 0
                                    }
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                            }
                            VStack {
                                Button {
                                    minute += 15
                                    if minute == 45 {
                                        minute = 45
                                    }
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                
                                Text("\(minute, specifier: "%02d")")
                                
                                Button {
                                    minute -= 15
                                    if minute == 0 {
                                        minute = 0
                                    }
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
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
                                let newTime = Double(hour) + Double(minute) / 60.0
                                let newCost = prices[time]!
                                prices.removeValue(forKey: time)
                                prices[newTime] = newCost
                                editedTime = nil
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                            Button {
                                // Cancel the edit
                                editedTime = nil
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                        } else {
                            Text("\(hour, specifier: "%02d"):\(minute, specifier: "%02d")")
                            Spacer()
                            Text(cost.formatted())
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editedTime = time
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }.tint(.blue)
                        
                        Button {
                            // Add a new price entry for this time
                            let newCost = Cost(amount: 0.0)
                            let newTime = time + 1 // Add one hour
                            prices[newTime] = newCost
                        } label: {
                            Label("Add", systemImage: "plus")
                        }.tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            prices.removeValue(forKey: time)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                Text("24:00")
                    
                
                
            }
        }
        .onAppear {
            if let seasonalPrice {
                // Edit the incoming seasonal price
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
        parentPriceElement: PriceElement,
        seasonalPrice: SeasonalPrice? = nil
    ) {
        self._navigationPath = navigationPath
        self.seasonalPrice = seasonalPrice
        self.parentPriceElement = parentPriceElement
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        if isNewSeasonalPrice {
            let newSeasonalPrice = SeasonalPrice(
                startDate: startDate,
                endDate: endDate
            )
            
            newSeasonalPrice.prices = prices
            
            // Relate to price element
            parentPriceElement.seasonalPrice = newSeasonalPrice
            
            // Insert into database
            modelContext.insert(newSeasonalPrice)
        } else {
            if let seasonalPrice = parentPriceElement.seasonalPrice {
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
}
