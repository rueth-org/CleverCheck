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
    @State private var defaultSOC: Double = 80
    
    @State private var isEditingSOC: Bool = false
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    private var editorTitle: String {
        car == nil ? "New Car" : "Edit Car"
    }
    
    var body: some View {
        Form {
            TextField("Make", text: $make)
            TextField("Model", text: $model)
            VStack {
                HStack {
                    Text("Default SOC")
                    Spacer()
                    Text("\(defaultSOC.formatted(.number))%")
                        .foregroundColor(isEditingSOC ? .red : .primary)
                }
                Slider(
                    value: $defaultSOC,
                    in: 50...100,
                    step: 5
                ) {
                    Text("Speed")
                } minimumValueLabel: {
                    Text("50%")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                } onEditingChanged: { editing in
                    isEditingSOC = editing
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
            if let car {
                // Edit the incoming car.
                make = car.make
                model = car.model
                defaultSOC = car.defaultSOC * 100
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
                car.defaultSOC = defaultSOC/100
            } else {
                let newCar = Car(make: make, model: model, defaultSOC: defaultSOC/100)
                modelContext.insert(newCar)
            }
            
            // Leave editor
            navigationPath.removeLast()
        }
    }
}
