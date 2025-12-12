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
        Dictionary(grouping: chargers) { $0.location?.name ?? NSLocalizedString("No location", comment: "") }
    }
    
    var body: some View {
        VStack {
            if chargers.isEmpty {
                Spacer()
                Image(systemName: "ev.charger")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No chargers found.")
                Spacer()
            } else {
                List {
                    ForEach(groupedChargers.keys.sorted(), id: \.self) { location in
                        Section(header: Text(location)) {
                            ForEach(groupedChargers[location]!, id: \.self) { charger in
                                NavigationLink(value: NavigationDestination.EditCharger(charger: charger)) {
                                    Text(charger.name)
                                }
                            }
                            .onDelete { offsets in
                                // Map offsets to the correct indices in chargers
                                let allChargersAtLocation = groupedChargers[location]!
                                let indicesToDelete = offsets.map { index in
                                    chargers.firstIndex(of: allChargersAtLocation[index])!
                                }
                                deleteCharger(at: IndexSet(indicesToDelete))
                            }
                        }
                    }
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
