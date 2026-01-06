//
//  ContentView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

struct HomeConsumptionsView: View {
    enum NavigationDestination: Hashable {
        case NewConsumption(location: Location?)
        case EditConsumption(homeConsumption: HomeConsumption)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @Binding var selectedLocation: Location?
    
    @State private var preselectedConsumptions: [HomeConsumption]? = nil
    
    @Query(filter: #Predicate<Location> { location in
        location.isArchived == false
    }, sort: \Location.name) private var locations: [Location]
    
    @Query(sort: [SortDescriptor(\HomeConsumption.validUntil), SortDescriptor(\HomeConsumption.name)]) private var homeConsumptions: [HomeConsumption]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?

    var body: some View {
        VStack {
            Text(selectedLocation?.name ?? NSLocalizedString("All locations", comment: ""))
                .font(.headline)
            HomeConsumptionsList(navigationPath: $navigationPath, preselectedConsumptions: $preselectedConsumptions, associatedLocation: selectedLocation)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Home Consumptions")
            }
            // Filter menu
            ToolbarItemGroup(placement: .topBarTrailing) {
                // TODO: Sorting of months
                
                // Filter by location
                Menu {
                    MenuHomeSelector(selectedHome: $selectedLocation, preselectedConsumptions: $preselectedConsumptions, allHomes: locations)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(selectedLocation == nil ? .primary : .blue)
                }
                
                // Add home consumption (or location if none available)
                Button(action: locations.isEmpty ? addLocation : addHomeConsumption) {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: [HomeConsumption].self) { homeConsumptions in
            if !homeConsumptions.isEmpty {
                HomeConsumptionAnalysis(navigationPath: $navigationPath, homeConsumptions: homeConsumptions, location: selectedLocation)
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
    
    init(
        navigationPath: Binding<NavigationPath>,
        selectedLocation: Binding<Location?>,
        preselectedConsumptions: [HomeConsumption]? = nil
    ) {
        self._navigationPath = navigationPath
        self._selectedLocation = selectedLocation
        self._preselectedConsumptions = State(initialValue: preselectedConsumptions)
    }
    
    private func addHomeConsumption() {
        if locations.isEmpty {
            activeAlert = .warning(message: "Please add a location first")
            showingAlert = true
        } else {
            navigationPath.append(NavigationDestination.NewConsumption(location: selectedLocation))
        }
    }
    
    private func addLocation() {
        navigationPath.append(LocationsView.NavigationDestination.NewLocation(location: selectedLocation))
    }
}
