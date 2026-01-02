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
    
    @Query private var chargers: [Charger]
    @Query private var homeConsumptions: [HomeConsumption]
    
    @State private var selectedLocation: Location? = nil
    @State private var isShowingArchived: Bool = false
    
    var predicate: Predicate<Location> {
        var predicate: Predicate<Location>
        if !isShowingArchived {
            predicate = #Predicate<Location> { location in
                location.isArchived == false
            }
        } else {
            predicate = .true
        }
        return predicate
    }
    
    var body: some View {
        List {
            DynamicList(
                predicate: predicate,
                sorting: [SortDescriptor(\Location.name)],
                emptyStateMessage: "No locations found.",
                emptyStateSystemImage: "mappin.and.ellipse"
            ) { location in
                NavigationLink(value: NavigationDestination.EditLocation(location: location)) {
                    Text(location.name)
                }
                .swipeActions {
                    if canDelete(location) {
                        Button(role: .destructive) {
                            deleteLocation(location)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            // no action
                        } label: {
                            Label("Cannot delete", systemImage: "trash")
                        }
                        .tint(.secondary)
                        .disabled(true)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Locations")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: {
                    withAnimation {
                        isShowingArchived.toggle()
                    }
                }) {
                    Image(systemName: isShowingArchived ? "archivebox.circle.fill" : "archivebox.circle")
                        .foregroundStyle(isShowingArchived ? .blue : .primary)
                }
                Button(action: newLocation) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private func newLocation() {
        navigationPath.append(NavigationDestination.NewLocation(location: nil))
    }
    
    private func deleteLocation(_ location: Location) {
        withAnimation {
            modelContext.delete(location)
        }
        try? modelContext.save()
    }
    
    private func canDelete(_ location: Location) -> Bool {
        !homeConsumptions.contains { $0.associatedLocation == location } && !chargers.contains { $0.location == location }
    }
}
