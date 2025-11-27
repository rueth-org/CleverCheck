//
//  CarsView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 25/11/2025.
//

import SwiftUI
import SwiftData

struct ChargersView: View {
    enum NavigationDestination: Hashable {
        case NewCharger
        case EditCharger(charger: Charger)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @Query(sort: \Charger.name) private var chargers: [Charger]
    @State private var selectedCharger: Charger? = nil
    
    private var groupedChargers: [String: [Charger]] {
        Dictionary(grouping: chargers) { $0.chargingLocation?.name ?? NSLocalizedString("No location", comment: "") }
    }
    
    var body: some View {
        List {
            ForEach(groupedChargers.keys.sorted(), id: \.self) { location in
                Section(header: Text(location)) {
                    ForEach(groupedChargers[location]!, id: \.self) { charger in
                        NavigationLink(value: NavigationDestination.EditCharger(charger: charger)) {
                            Text(charger.name)
                        }
                    }
                    .onDelete(perform: deleteCharger)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Chargers")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button(action: newCharger) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private func newCharger() {
        navigationPath.append(NavigationDestination.NewCharger)
    }
    
    private func deleteCharger(at offsets: IndexSet) {
        // TODO check if can be deleted
        for offset in offsets {
            // Find charger in our query
            let charger = chargers[offset]

            // Delete it from the context
            withAnimation {
                modelContext.delete(charger)
            }
        }
    }
}
