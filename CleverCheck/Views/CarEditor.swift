//
//  CarView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 24/11/2025.
//

import SwiftUI

struct CarEditor: View {
    private enum Field: Int, Hashable {
        case netBatteryCapacity, maxChargingPower
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    let car: Car?
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var defaultSOC: Double = 0.8
    @State private var netBatteryCapacityKWh: Double = 50
    @State private var enterNetBatteryCapacity: Bool = false
    @State private var maxChargingPowerKW: Double = 200
    @State private var enterMaxChargingPower: Bool = false
    @State private var isArchived: Bool = false
    
    @State private var isEditingSOC: Bool = false
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?
    
    @FocusState private var focusedField: Field?
    
    private let minSOC: Double = 0.5
    private let maxSOC: Double = 1.0
    
    private var editorTitle: String {
        car == nil ? NSLocalizedString("New Car", comment: "") : NSLocalizedString("Edit Car", comment: "")
    }
    
    var body: some View {
        Form {
            TextField("Make", text: $make)
            TextField("Model", text: $model)
            
            VStack {
                HStack {
                    Text("Default SOC")
                    Spacer()
                    Text(defaultSOC.formatted(.percent))
                        .foregroundColor(isEditingSOC ? .red : .primary)
                }
                Slider(
                    value: $defaultSOC,
                    in: 0.5...1.0,
                    step: 0.05
                ) {
                    Text("Default SOC")
                } minimumValueLabel: {
                    Text(minSOC.formatted(.percent))
                        .font(.caption)
                } maximumValueLabel: {
                    Text(maxSOC.formatted(.percent))
                        .font(.caption)
                } onEditingChanged: { editing in
                    isEditingSOC = editing
                }
            }
            
            // Net battery capacity (optional)
            if enterNetBatteryCapacity {
                HStack {
                    Text("Net battery capacity")
                    Spacer()
                    TextField("", value: $netBatteryCapacityKWh, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .netBatteryCapacity)
                    Text(UnitEnergy.kilowattHours.symbol)
                    Button {
                        deleteNetBatteryCapacity()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                        
                    }
                }
            } else {
                // Offer to enter capacity
                HStack {
                    Text("Net battery capacity")
                    Spacer()
                    Button {
                        focusedField = .netBatteryCapacity
                        enterNetBatteryCapacity = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            
            // Max charging power (optional)
            if enterMaxChargingPower {
                HStack {
                    Text("Maximum charging power")
                    Spacer()
                    TextField("", value: $maxChargingPowerKW, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .maxChargingPower)
                    Text(UnitPower.kilowatts.symbol)
                    Button {
                        deleteMaxChargingPower()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
            } else {
                // Offer to enter capacity
                HStack {
                    Text("Maximum charging power")
                    Spacer()
                    Button {
                        focusedField = .maxChargingPower
                        enterMaxChargingPower = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            
            Toggle("Archived", isOn: $isArchived)
                .padding(.top)
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
            if let car {
                // Edit the incoming car.
                make = car.make
                model = car.model
                defaultSOC = car.defaultSOC
                if let netBatteryCapacityKWh = car.netBatteryCapacityKWh {
                    enterNetBatteryCapacity = true
                    self.netBatteryCapacityKWh = netBatteryCapacityKWh
                }
                if let maxChargingPowerKW = car.maxChargingPowerkW {
                    enterMaxChargingPower = true
                    self.maxChargingPowerKW = maxChargingPowerKW
                }
                isArchived = car.isArchived
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
    
    private func deleteNetBatteryCapacity() {
        enterNetBatteryCapacity = false
    }
    
    private func deleteMaxChargingPower() {
        enterMaxChargingPower = false
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        let make = self.make.trimmingCharacters(in: .whitespaces)
        let model = self.model.trimmingCharacters(in: .whitespaces)
        if make.isEmpty || model.isEmpty {
            activeAlert = SimpleAlert(type: .error(message: "Make and model are required."))
            showingAlert = true
        } else {
            if let car {
                // Edit the car
                car.make = make
                car.model = model
                car.defaultSOC = defaultSOC
                if enterNetBatteryCapacity {
                    car.netBatteryCapacityKWh = netBatteryCapacityKWh
                }
                if enterMaxChargingPower {
                    car.maxChargingPowerkW = maxChargingPowerKW
                }
                car.isArchived = isArchived
            } else {
                let newCar = Car(make: make, model: model, defaultSOC: defaultSOC)
                if enterNetBatteryCapacity {
                    newCar.netBatteryCapacityKWh = netBatteryCapacityKWh
                }
                if enterMaxChargingPower {
                    newCar.maxChargingPowerkW = maxChargingPowerKW
                }
                newCar.isArchived = isArchived
                modelContext.insert(newCar)
            }
            
            // Save data and leave editor
            try? modelContext.save()
            navigationPath.removeLast()
        }
    }
}
