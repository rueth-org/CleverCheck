//
//  CarView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 24/11/2025.
//

import SwiftUI
import SwiftData

struct ChargerEditor: View {
    private enum Field: Int, Hashable {
        case maxPower
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    let charger: Charger?
    
    @Query(filter: #Predicate<Location> { location in
        location.isArchived == false
    }, sort: \Location.name) private var locations: [Location]
    
    @State private var name: String = ""
    @State private var location: Location? = nil
    @State private var maxPower: Measurement<UnitPower> = .init(value: 0, unit: UserSettings.shared.powerUnit)
    @State private var enterMaxPower: Bool = false
    @State private var isArchived: Bool = false
    
    @FocusState private var focusedField: Field?
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?
    
    private var editorTitle: String {
        charger == nil ? NSLocalizedString("New Charger", comment: "") : NSLocalizedString("Edit Charger", comment: "")
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $name)
            
            // Location
            Picker("Location", selection: $location) {
                Text("- none -").tag(nil as Location?)
                ForEach(locations, id: \.id) { location in
                    Text(location.name).tag(location)
                }
            }
            
            // Max Power (optional)
            if enterMaxPower {
                HStack {
                    Text("Maximum Power")
                    Spacer()
                    TextField("", value: $maxPower.value, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .maxPower)
                    Text(maxPower.unit.symbol)
                    Button {
                        deleteMaxPower()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
            } else {
                // Offer to enter mileage
                HStack {
                    Text("Maximum Power")
                    Spacer()
                    Button {
                        focusedField = .maxPower
                        enterMaxPower = true
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
            if let charger {
                // Edit the incoming charger.
                name = charger.name
                location = charger.location
                if let maxPower = charger.maxPower {
                    enterMaxPower = true
                    self.maxPower = maxPower
                }
                isArchived = charger.isArchived
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
    
    private func deleteMaxPower() {
        enterMaxPower = false
        maxPower = .init(value: 0, unit: UserSettings.shared.powerUnit)
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        let name = self.name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            activeAlert = SimpleAlert(type: .error(message: "Name is required."))
            showingAlert = true
        } else {
            if let charger {
                // Edit the location
                charger.name = name
                charger.location = location
                if !checkMaxPower(charger: charger) { return }
                charger.isArchived = isArchived
            } else {
                let newCharger = Charger(name: name, location: location)
                if !checkMaxPower(charger: newCharger) { return }
                newCharger.isArchived = isArchived
                modelContext.insert(newCharger)
            }
            
            // Save data and leave editor
            try? modelContext.save()
            navigationPath.removeLast()
        }
    }
    
    private func checkMaxPower(charger: Charger) -> Bool {
        if enterMaxPower {
            if maxPower.value == 0 {
                activeAlert = SimpleAlert(type: .warning(message: "Max power must be greater than 0."))
                showingAlert = true
                return false
            }
            charger.maxPower = self.maxPower
            return true
        } else {
            charger.maxPower = nil
            return true
        }
    }
}
