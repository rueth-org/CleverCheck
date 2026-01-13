//
//  CarView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 24/11/2025.
//

import SwiftUI

struct LocationEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    let location: Location?
    
    @State private var name: String = ""
    @State private var isArchived: Bool = false
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?
    
    private var editorTitle: String {
        location == nil ? NSLocalizedString("New Location", comment: "") : NSLocalizedString("Edit Location", comment: "")
    }
    
    var body: some View {
        Form {
            TextField("Name", text: $name)
            
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
            if let location {
                // Edit the incoming location.
                name = location.name
                isArchived = location.isArchived
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
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        let name = self.name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            activeAlert = SimpleAlert(type: .error(message: "Name is required."))
            showingAlert = true
        } else {
            if let location {
                // Edit the location
                location.name = name
                location.isArchived = isArchived
            } else {
                let newLocation = Location(name: name)
                newLocation.isArchived = isArchived
                modelContext.insert(newLocation)
            }
            
            // Save data and leave editor
            try? modelContext.save()
            navigationPath.removeLast()
        }
    }
}
