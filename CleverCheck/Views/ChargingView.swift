//
//  ChargingView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/12/2025.
//

import SwiftUI
import SwiftData

struct ChargingView: View {
    enum NavigationDestination: Hashable {
        case ChargingSessions
    }
    
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    @State private var selectedCar: Car? = nil
    @State private var selectedSession: ChargingSession? = nil
    @State private var timeBox: TimeBox? = nil
    
    enum Chart {
        case charging, consumption
    }
    @State private var selectedChart: Chart = .charging
    
    @Query private var vehicles: [Car]
    
    var chargingData: ChargingData? {
        if let selectedCar, let timeBox {
            return try? ChargingData(modelContext: modelContext, vehicle: selectedCar, timeBox: timeBox)
        } else {
            return nil
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if let chargingData, let timeBox {
                    
                    // The date selection part
                    
                    Text(selectedCar?.description ?? "No car selected")
                        .font(Font.title.bold())
                    
                    // The date picker
                    TimeBoxPicker(timeBox: timeBox)
                    
                    // The data part
                    if chargingData.chargingSessions.isEmpty {
                        HStack {
                            Spacer()
                            Text("No data")
                                .italic()
                                .foregroundStyle(Color.secondary)
                            Spacer()
                        }
                    } else {
                        // The picker to choose which data to display
                        Picker("Choose data set", selection: $selectedChart) {
                            Text("Charging data").tag(Chart.charging)
                            Text("Consumption").tag(Chart.consumption)
                        }
                        .pickerStyle(.palette)
                        
                        ChargingViewChart(chargingData: chargingData, selectedChart: selectedChart, onBarTap: { dateKey in
                            timeBox.switchResolution(dateKey)
                        })
                        
                        // The summary data
                        ChargingViewSummary(chargingData: chargingData)
                    }
                } else {
                    Text("Select vehicle to show data").italic()
                }
                
                // The charging sessions button
                Button(action: {
                    navigationPath.append(NavigationDestination.ChargingSessions)
                }) {
                    Text("Charging Sessions")
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
                    Text("Charging")
                }
                // Filter menu
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        MenuCarSelector(selectedCar: $selectedCar, timeBox: .constant(nil), allCars: vehicles)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(selectedCar == nil ? .primary : .blue)
                    }
                }
                // Add session (or car if none available)
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: vehicles.isEmpty ? addCar : addSession) {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: NavigationDestination.self) { screen in
                switch screen {
                case .ChargingSessions:
                    ChargingSessionsView(navigationPath: $navigationPath, selectedCar: $selectedCar, timeBox: timeBox)
                }
            }
            .navigationDestination(for: ChargingSessionsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewSession(let selectedCar):
                    ChargingSessionEditor(navigationPath: $navigationPath, chargingSession: nil, selectedCar: selectedCar)
                case .EditSession(chargingSession: let chargingSession, let selectedCar):
                    ChargingSessionEditor(navigationPath: $navigationPath, chargingSession: chargingSession, selectedCar: selectedCar)
                }
            }
            .navigationDestination(for: CarsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewCar:
                    CarEditor(navigationPath: $navigationPath, car: nil)
                case .EditCar(car: let car):
                    CarEditor(navigationPath: $navigationPath, car: car)
                }
            }
        }
        .sheet(item: $selectedSession) { _ in
            if let chargingData {
                ChargingSessionDetails(navigationPath: $navigationPath, selectedSession: $selectedSession, vehicle: selectedCar, allSessions: chargingData.chargingSessions)
            }
        }
        .onAppear {
            if !vehicles.isEmpty {
                // First check if selectedVehicle still is available (could have been deleted)
                if let selectedCar {
                    if !vehicles.contains(selectedCar) {
                        self.selectedCar = nil
                    }
                }
                
                if let selectedCarId = UserSettings.shared.selectedCarId {
                    if let selectedCar = vehicles.first(where: { $0.id.uuidString == selectedCarId }) {
                        self.selectedCar = selectedCar
                    }
                }
                
                // If still no vehicle selected and there's only one available, select it
                if selectedCar == nil && vehicles.count == 1 {
                    selectedCar = vehicles.first
                    UserSettings.shared.selectedCarId = vehicles.first?.id.uuidString
                }
            }
            
            self.timeBox = TimeBox(
                selectedDate: Date.now.startOfMonth,
                selectedResolution: .monthly,
                allowedResolutions: [.daily, .monthly, .yearly],
                selectIndividualItem: selectIndividualSession
            )
        }
    }
    
    init() {
        // Initialize car query
        let predicate = #Predicate<Car> { car in
            car.isArchived == false
        }
        _vehicles = Query(
            filter: predicate,
            sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]
        )
    }
    
    private func addSession() {
        navigationPath.append(ChargingSessionsView.NavigationDestination.NewSession(selectedCar: selectedCar))
    }
    
    private func addCar() {
        navigationPath.append(CarsView.NavigationDestination.NewCar)
    }
    
    private func selectIndividualSession(date: Date) {
        if let chargingData {
            // Try to identify session
            if chargingData.chargingSessions.count == 1 {
                // There is only one session
                selectedSession = chargingData.chargingSessions.first!
            } else {
                // Try to match endTime
                for session in chargingData.chargingSessions {
                    if session.endTime == date {
                        selectedSession = session
                        break
                    }
                }
            }
        }
    }
}

