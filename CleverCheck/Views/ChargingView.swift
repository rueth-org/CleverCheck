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
    @State private var timeBox: TimeBox
    
    @State private var showCarInfo: Bool = false
    
    @Query private var vehicles: [Car]
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                if let selectedCar {
                    HStack {
                        Text(selectedCar.description)
                            .font(Font.title.bold())
                    }.padding(.horizontal)
                    
                    // The date picker
                    TimeBoxPicker(timeBox: timeBox)
                        .padding(.horizontal)
                    
                    // The data part
                    ChargingViewChart(car: selectedCar, timeBox: timeBox, onBarTap: { dateKey in
                        timeBox.switchResolution(dateKey)
                    })
                    .padding(.horizontal)
                } else {
                    Text("Select vehicle to show data")
                        .italic()
                        .padding()
                }
                
                // The spacer to move the charging sessions button to the bottom of the screen
                Spacer()
                
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
                        MenuCarSelector(selectedCar: $selectedCar, allCars: vehicles)
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
            if let selectedCar {
                ChargingSessionDetails(navigationPath: $navigationPath, selectedSession: $selectedSession, vehicle: selectedCar, allSessions: selectedCar.chargingSessions(in: timeBox))
                    .presentationDragIndicator(.visible)
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
            
            self.timeBox.selectIndividualItem = selectIndividualSession
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
        _timeBox = State(initialValue: TimeBox(
            selectedDate: Date.now,
            selectedResolution: .monthly,
            allowedResolutions: [.daily, .monthly, .yearly],
            selectIndividualItem: { _ in }
        ))
    }
    
    private func addSession() {
        navigationPath.append(ChargingSessionsView.NavigationDestination.NewSession(selectedCar: selectedCar))
    }
    
    private func addCar() {
        navigationPath.append(CarsView.NavigationDestination.NewCar)
    }
    
    private func selectIndividualSession(date: Date) {
        if let selectedCar {
            let chargingSessions = selectedCar.chargingSessions(in: timeBox)
            // Try to identify session
            if chargingSessions.count == 1 {
                // There is only one session
                selectedSession = chargingSessions.first!
            } else {
                // Try to match endTime
                for session in chargingSessions {
                    if session.endTime == date {
                        selectedSession = session
                        break
                    }
                }
            }
        }
    }
}

