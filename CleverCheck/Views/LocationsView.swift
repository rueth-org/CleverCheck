//
//  CarsView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 25/11/2025.
//

import SwiftUI
import SwiftData

struct LocationsView: View {
    enum NavigationDestination: Hashable {
        case NewLocation(location: Location?)
        case EditLocation(location: Location)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @Query(sort: \Location.name) private var locations: [Location]
    @State private var selectedLocation: Location? = nil
    
    var body: some View {
        VStack {
            if locations.isEmpty {
                Spacer()
                Image(systemName: "mappin.and.ellipse")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No locations found.")
                Spacer()
            } else {
                List {
                    ForEach(locations, id: \.self) { location in
                        NavigationLink(value: NavigationDestination.EditLocation(location: location)) {
                            Text(location.name)
                        }
                    }
                    .onDelete(perform: deleteLocation)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Locations")
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
        navigationPath.append(NavigationDestination.NewLocation(location: nil))
    }
    
    private func deleteLocation(at offsets: IndexSet) {
        // TODO check if can be deleted
        for offset in offsets {
            // Find location in our query
            let location = locations[offset]

            // Delete it from the context
            withAnimation {
                modelContext.delete(location)
            }
        }
    }
}
