//
//  CarView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 24/11/2025.
//

import SwiftUI

struct CarView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    var car: Car?
    @State var make: String = ""
    @State var model: String = ""
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    var body: some View {
        VStack {
            ZStack {
                // The form
                Form {
                    TextField("Make", text: $make)
                    TextField("Model", text: $model)
                }
                .safeAreaPadding(EdgeInsets(top: 0, leading: 0, bottom: ActionButton.safeButtonSpace, trailing: 0)) // Required to avoid the content to be hidden by the Edit and Save buttons
                
                // The overlaying buttons
                VStack {
                    Spacer()
                    HStack {
                        // The cancel button
                        Button(role: .cancel) {
                            // Cancel and exit
                            cancelAndExit()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill").imageScale(.large)
                                Text("Cancel")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(CancelButton())
                        
                        // The save button
                        Button {
                            saveAndExit()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").imageScale(.large).foregroundStyle(.green)
                                Text("Save")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(ActionButton())
                    }
                    .padding()
                    .fixedSize(horizontal: false, vertical: true)
                }
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
    
    init(navigationPath: Binding<NavigationPath>, car: Car? = nil) {
        self._navigationPath = navigationPath
        if let car {
            self.car = car
            self.make = car.make
            self.model = car.model
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
            let car = Car(make: make, model: model)
            modelContext.insert(car)
            navigationPath.removeLast()
        }
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()
    CarView(navigationPath: $navigationPath)
}
