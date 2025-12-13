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
        case NewConsumption
        case EditConsumption(homeConsumption: HomeConsumption)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    
    @Query private var locations: [Location]
    @Query(sort: [SortDescriptor(\HomeConsumption.validUntil), SortDescriptor(\HomeConsumption.name)]) private var homeConsumptions: [HomeConsumption]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    @State private var selectedLocation: Location? = nil
    
    var body: some View {
        VStack {
            HStack {
                Text("Location")
                Button {
                    addLocation()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.gray)
                }
                Spacer()
                // Location selector
                Picker("Location", selection: $selectedLocation) {
                    Text("All locations").tag(nil as Location?)
                    ForEach(locations, id: \.self) { location in
                        Text(location.name).tag(location)
                    }
                }
            }
            .padding(.horizontal)
            
            HomeConsumptionsList(navigationPath: $navigationPath, associatedLocation: selectedLocation)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Home Consumptions")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button(action: addHomeConsumption) {
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
    
    private func addHomeConsumption() {
        if locations.isEmpty {
            activeAlert = .warning(message: "Please add a location first")
            showingAlert = true
        } else {
            navigationPath.append(NavigationDestination.NewConsumption)
        }
    }
    
    private func addLocation() {
        navigationPath.append(LocationsView.NavigationDestination.NewLocation(location: selectedLocation))
    }
}
