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
    
    struct ConsumptionContainer: Identifiable {
        let id = UUID()
        let consumptions: [HomeConsumption]
    }
    
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    @State private var selectedLocation: Location? = nil
    @State private var selectedConsumptions: ConsumptionContainer? = nil
    @State private var timeBox: TimeBox = TimeBox(
        selectedDate: Date.now.startOfMonth,
        selectedResolution: .yearly,
        allowedResolutions: [.yearly],
        selectIndividualItem: { _ in }
    )
    @State private var showHomeData: Bool = true
    @State private var showChargingData: Bool = true
    
    @State private var showingHomeConsumptionAnalysis: Bool = false
    
    enum Chart {
        case energy, cost
    }
    @State private var selectedChart: Chart = .energy
    
    @Query(filter: #Predicate<Location> { location in
        location.isArchived == false
    }, sort: \Location.name) private var locations: [Location]
    
    var homeData: HomeData? {
        if let selectedLocation {
            return try? HomeData(modelContext: modelContext, location: selectedLocation, timeBox: timeBox)
        } else {
            return nil
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if let homeData {
                    // The date selection part
                    Text(selectedLocation?.name ?? "No location selected")
                        .font(Font.title.bold())
                    
                    // The date picker
                    TimeBoxPicker(timeBox: timeBox)
                    
                    // The picker to choose which data to display
                    Picker("Choose data set", selection: $selectedChart) {
                        Text("Energy").tag(Chart.energy)
                        Text("Cost").tag(Chart.cost)
                    }
                    .pickerStyle(.palette)
                    
                    // The data part
                    HomeViewChart(
                        homeData: homeData,
                        selectedChart: selectedChart,
                        showHomeData: $showHomeData,
                        showChargingData: $showChargingData,
                        onBarTap: { dateKey in
                            timeBox.switchResolution(dateKey)
                        }
                    )
                    .id(homeData.id)
                    
                    // The summary data
                    HomeViewSummary(homeData: homeData)
                } else {
                    Text("Select location").italic()
                }
                
                Button(action: {
                    navigationPath.append(NavigationDestination.HomeConsumptions)
                }) {
                    Text("Home Consumptions")
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
                        MenuHomeSelector(selectedHome: $selectedLocation, timeBox: .constant(nil), allHomes: locations)
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
                    HomeConsumptionsView(navigationPath: $navigationPath, selectedLocation: $selectedLocation, timeBox: timeBox, selectedConsumptions: $selectedConsumptions)
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
        .sheet(item: $selectedConsumptions) { selectedConsumptions in
            HomeConsumptionAnalysis(
                homeConsumptions: selectedConsumptions.consumptions,
                location: selectedLocation
            )
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !locations.isEmpty {
                // First check if selectedLocation still is available (could have been deleted)
                if let selectedLocation {
                    if !locations.contains(selectedLocation) {
                        self.selectedLocation = nil
                    }
                }
                
                if let selectedLocationId = UserSettings.shared.selectedLocationId {
                    if let selectedLocation = locations.first(where: { $0.id.uuidString == selectedLocationId }) {
                        self.selectedLocation = selectedLocation
                    }
                }
                
                // If still no location selected and there's only one available, select it
                if selectedLocation == nil && locations.count == 1 {
                    selectedLocation = locations.first
                    UserSettings.shared.selectedLocationId = locations.first?.id.uuidString
                }
            }
            
            timeBox.selectIndividualItem = selectMonth
        }
    }
    
    private func addLocation() {
        navigationPath.append(LocationsView.NavigationDestination.NewLocation(location: nil))
    }
    
    private func addHomeConsumption() {
        navigationPath.append(HomeConsumptionsView.NavigationDestination.NewConsumption(location: selectedLocation))
    }
    
    private func selectMonth(date: Date) {
        if let homeData {
            // Collect all consumptions ending in the selected month
            let calendar = Calendar.current
            let selectedYear = calendar.component(.year, from: date)
            let selectedMonth = calendar.component(.month, from: date)
            let selectedConsumptions = homeData.homeConsumptions.filter { consumption in
                calendar.component(.year, from: consumption.validUntil) == selectedYear &&
                calendar.component(.month, from: consumption.validUntil) == selectedMonth
            }
            self.selectedConsumptions = ConsumptionContainer(consumptions: selectedConsumptions)
        }
    }
}

