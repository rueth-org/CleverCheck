//
//  CarsView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 25/11/2025.
//

import SwiftUI
import SwiftData

struct ChargingLocationsView: View {
    enum NavigationDestination: Hashable {
        case NewLocation
        case EditLocation(chargingLocation: ChargingLocation)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @Query(sort: \ChargingLocation.name) private var charingLocations: [ChargingLocation]
    @State private var selectedLocation: ChargingLocation? = nil
    
    var body: some View {
        List {
            ForEach(charingLocations, id: \.self) { chargingLocation in
                NavigationLink(value: NavigationDestination.EditLocation(chargingLocation: chargingLocation)) {
                    Text(chargingLocation.name)
                }
            }
            .onDelete(perform: deleteLocation)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Charging Locations")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button(action: newLocation) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private func newLocation() {
        navigationPath.append(NavigationDestination.NewLocation)
    }
    
    private func deleteLocation(at offsets: IndexSet) {
        for offset in offsets {
            // Find location in our query
            let location = charingLocations[offset]

            // Delete it from the context
            modelContext.delete(location)
        }
    }
}
