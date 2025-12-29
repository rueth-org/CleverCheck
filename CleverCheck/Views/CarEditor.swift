//
//  CarView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 24/11/2025.
//

import SwiftUI

struct CarEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    let car: Car?
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var defaultSOC: Double = 0.8
    @State private var isArchived: Bool = false
    
    @State private var isEditingSOC: Bool = false
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
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
                    Text("Speed")
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
                isArchived = car.isArchived
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
        let make = self.make.trimmingCharacters(in: .whitespaces)
        let model = self.model.trimmingCharacters(in: .whitespaces)
        if make.isEmpty || model.isEmpty {
            activeAlert = .error(message: "Make and model are required.")
            showingAlert = true
        } else {
            if let car {
                // Edit the car
                car.make = make
                car.model = model
                car.defaultSOC = defaultSOC
                car.isArchived = isArchived
            } else {
                let newCar = Car(make: make, model: model, defaultSOC: defaultSOC)
                newCar.isArchived = isArchived
                modelContext.insert(newCar)
            }
            
            // Save data and leave editor
            try? modelContext.save()
            navigationPath.removeLast()
        }
    }
}
