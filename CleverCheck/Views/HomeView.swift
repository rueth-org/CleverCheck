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
    
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    @State private var selectedLocation: Location? = nil
    @State private var timeBox: TimeBox = TimeBox(
        selectedDate: Date.now,
        selectedResolution: .yearly,
        allowedResolutions: [.yearly, .monthly],
        selectIndividualItem: { _ in }
    )
    @State private var showHomeData: Bool = true
    @State private var showHomeChargingData: Bool = true
    @State private var showRefundedChargingData: Bool = true
    
    @Query(filter: #Predicate<Location> { location in
        location.isArchived == false
    }, sort: \Location.name) private var locations: [Location]
    
    // Observe UserSettings so changes to published properties cause the view to refresh
    @ObservedObject private var settings = UserSettings.shared

    private var data: [Location.Data] {
        guard let selectedLocation else { return [] }
        return selectedLocation.data(in: timeBox, useRelatedConsumption: settings.useRelatedConsumptions, modelContext: modelContext)
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                if let selectedLocation {
                    // The date selection part
                    Text(selectedLocation.name)
                        .font(Font.title.bold())
                        .padding(.horizontal)
                    
                    // The date picker
                    TimeBoxPicker(timeBox: timeBox)
                        .padding(.horizontal)
                    
                    // The data part
                    HomeViewChart(
                        location: selectedLocation,
                        timeBox: timeBox,
                        data: data,
                        showHomeData: $showHomeData,
                        showHomeChargingData: $showHomeChargingData,
                        showRefundedChargingData: $showRefundedChargingData,
                        onBarTap: { dateKey in
                            timeBox.switchResolution(dateKey)
                        }
                    )
                    .id(selectedLocation.id)
                    .padding(.horizontal)
                } else {
                    Text("Select location")
                        .italic()
                        .padding()
                }
                
                Button(action: {
                    navigationPath.append(NavigationDestination.HomeConsumptions)
                }) {
                    Text("Home Consumptions")
                        .textStyle(BlueButtonText())
                }
                .buttonStyle(BlueButton())
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Home")
                }
                // Filter menu
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        MenuHomeSelector(selectedHome: $selectedLocation, allHomes: locations)
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
                    HomeConsumptionsView(navigationPath: $navigationPath, selectedLocation: $selectedLocation, timeBox: timeBox)
                }
            }
            .navigationDestination(for: HomeConsumptionsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewConsumption(let location):
                    HomeConsumptionEditor(navigationPath: $navigationPath, selectedLocation: location)
                case .EditConsumption(homeConsumption: let HomeConsumption):
                    HomeConsumptionEditor(navigationPath: $navigationPath, homeConsumption: HomeConsumption)
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
            .navigationDestination(for: HomeConsumptionEditor.NavigationDestination.self) { destination in
                switch destination {
                case .NewPriceElement(let homeConsumption, let energyUnitSymbol):
                    PriceElementEditor(
                        navigationPath: $navigationPath,
                        priceElement: nil,
                        homeConsumption: homeConsumption,
                        energyUnitSymbol: energyUnitSymbol
                    )
                case .EditPriceElement(let homeConsumption, let priceElement, let energyUnitSymbol):
                    PriceElementEditor(
                        navigationPath: $navigationPath,
                        priceElement: priceElement,
                        homeConsumption: homeConsumption,
                        energyUnitSymbol: energyUnitSymbol
                    )
                }
            }
        }
        .onAppear {
            if !locations.isEmpty {
                // First check if selectedLocation still is available (could have been deleted)
                if let selectedLocation {
                    if !locations.contains(selectedLocation) {
                        self.selectedLocation = nil
                    }
                }
                
                if let selectedLocationId = settings.selectedLocationId {
                    if let selectedLocation = locations.first(where: { $0.id.uuidString == selectedLocationId }) {
                        self.selectedLocation = selectedLocation
                    }
                }
                
                // If still no location selected and there's only one available, select it
                if selectedLocation == nil && locations.count == 1 {
                    selectedLocation = locations.first
                    settings.selectedLocationId = locations.first?.id.uuidString
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

