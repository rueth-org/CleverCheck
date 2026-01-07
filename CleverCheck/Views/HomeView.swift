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
    @State private var selectedDate: Date = Date.now.startOfYear
    @State private var selectedConsumption: HomeConsumption? = nil
    
    enum Chart {
        case energy, cost
    }
    @State private var selectedChart: Chart = .energy
    
    @Query(filter: #Predicate<Location> { location in
        location.isArchived == false
    }, sort: \Location.name) private var locations: [Location]
    
    var timePeriod: (Date, Date) {
        (selectedDate.startOfYear, selectedDate.endOfYear)
    }
    
    var homeData: HomeData? {
        if let selectedLocation = selectedLocation {
            return try? HomeData(modelContext: modelContext, location: selectedLocation, date: selectedDate)
        } else {
            return nil
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if let homeData = homeData {
                    // The date selection part
                    Text(selectedLocation?.name ?? "No location selected")
                        .font(Font.title.bold())
                    
                    HStack(alignment: .center) {
                        Button(action: decreaseYear) {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Text(verbatim: "\(Calendar.current.component(.year, from: selectedDate))")
                        
                        Spacer()
                        
                        Button(action: increaseYear) {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // The picker to choose which data to display
                    Picker("Choose data set", selection: $selectedChart) {
                        Text("Energy").tag(Chart.energy)
                        Text("Cost").tag(Chart.cost)
                    }
                    .pickerStyle(.palette)
                    
                    // The data part
                    HomeViewChart(homeData: homeData, selectedChart: selectedChart)
                } else {
                    Text("Select location").italic()
                }
                
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
                        MenuHomeSelector(selectedHome: $selectedLocation, selectedTimePeriod: .constant(nil), allHomes: locations)
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
            }
            .navigationDestination(for: NavigationDestination.self) { screen in
                switch screen {
                case .HomeConsumptions:
                    HomeConsumptionsView(navigationPath: $navigationPath, selectedLocation: $selectedLocation, selectedTimePeriod: timePeriod)
                }
            }
            .navigationDestination(for: HomeConsumptionsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewConsumption(let location):
                    let newHomeConsumption = HomeConsumption(
                        name: "",
                        validFrom: Date.now.startOfMonth,
                        validUntil: Date.now.endOfMonth,
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
    
    private func decreaseYear() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .year, value: -1, to: selectedDate)!
        }
    }
    
    private func increaseYear() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .year, value: 1, to: selectedDate)!
        }
    }
}
