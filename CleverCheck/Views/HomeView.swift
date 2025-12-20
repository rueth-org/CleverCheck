//
//  HomeView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/12/2025.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    enum NavigationDestination: Hashable {
        case HomeConsumptions
    }
    
    @State private var navigationPath = NavigationPath()
    @State private var selectedLocation: Location? = nil
    
    @Query(sort: \Location.name) private var locations: [Location]
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                Button(action: {
                    navigationPath.append(NavigationDestination.HomeConsumptions)
                }) {
                    Text("Home Consumption")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .font(.system(size: 18))
                        .padding()
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                .background(Color.blue)
                .cornerRadius(25)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Home")
                }
                // Filter menu
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { selectedLocation = nil }) {
                            Text("All locations")
                        }
                        ForEach(locations, id: \.self) { location in
                            Button(action: { selectedLocation = location }) {
                                Text(location.name)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(selectedLocation == nil ? .primary : .blue)
                    }
                }
                // Add home consumption (or location if none available)
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: locations.isEmpty ? addLocation : addHomeConsumption) {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: NavigationDestination.self) { screen in
                switch screen {
                case .HomeConsumptions:
                    HomeConsumptionsView(navigationPath: $navigationPath, selectedLocation: $selectedLocation)
                }
            }
            .navigationDestination(for: HomeConsumptionsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewConsumption(let location):
                    let newHomeConsumption = HomeConsumption(
                        name: "",
                        validFrom: Date.now.startDateOfMonth,
                        validUntil: Date.now.endDateOfMonth,
                        consumption: .init(value: 0.0, unit: .kilowattHours),
                        consumptionIncludedElsewhere: false,
                        associatedLocation: location
                    )
                    HomeConsumptionEditor(navigationPath: $navigationPath, homeConsumption: newHomeConsumption, isNew: true)
                case .EditConsumption(homeConsumption: let HomeConsumption):
                    HomeConsumptionEditor(navigationPath: $navigationPath, homeConsumption: HomeConsumption, isNew: false)
                }
            }
            .navigationDestination(for: LocationsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewLocation(location: let location):
                    LocationEditor(navigationPath: $navigationPath, location: location)
                case .EditLocation(location: let location):
                    LocationEditor(navigationPath: $navigationPath, location: location)
                }
            }
        }
    }
    
    private func addLocation() {
        navigationPath.append(LocationsView.NavigationDestination.NewLocation(location: nil))
    }
    
    private func addHomeConsumption() {
        navigationPath.append(HomeConsumptionsView.NavigationDestination.NewConsumption(location: selectedLocation))
    }
}
