//
//  ContentView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

struct ChargingSessionsView: View {
    enum NavigationDestination: Hashable {
        case NewSession(selectedCar: Car?)
        case EditSession(chargingSession: ChargingSession, selectedCar: Car?)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @State private var selectedCar: Car?
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var vehicles: [Car]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    var sessionFilter: [String: Predicate<ChargingSession>] {
        var result: [String: Predicate<ChargingSession>] = [:]
        if selectedCar == nil {
            // Display all vehicles
            for vehicle in vehicles {
                let vehicleID = vehicle.persistentModelID
                result[vehicle.description] = #Predicate<ChargingSession> { chargingSession in
                    if let carID = chargingSession.chargingCostPlan?.car?.persistentModelID {
                        return carID == vehicleID
                    } else {
                        return false
                    }
                }
            }
        } else {
            // Only display selected car
            let vehicleID = selectedCar!.persistentModelID
            result[selectedCar!.description] = #Predicate<ChargingSession> { chargingSession in
                if let carID = chargingSession.chargingCostPlan?.car?.persistentModelID {
                    return carID == vehicleID
                } else {
                    return false
                }
            }
        }
        return result
    }
    
    var body: some View {
        List(sessionFilter.keys.sorted(), id: \.self) { carDescription in
            Section(header: Text(carDescription)) {
                // List of charging sessions
                DynamicList(
                    predicate: sessionFilter[carDescription]!,
                    sorting: [SortDescriptor(\ChargingSession.endTime)],
                    emptyStateMessage: "No charging sessions found.",
                    emptyStateSystemImage: "bolt.car",
                    activeAlert: $activeAlert,
                    showingAlert: $showingAlert,
                    canDelete: { chargingSession in
                        // No restrictions on deletion
                        return true
                    },
                    content: { chargingSession in
                        NavigationLink(value: ChargingSessionsView.NavigationDestination.EditSession(chargingSession: chargingSession, selectedCar: selectedCar)) {
                            VStack {
                                HStack {
                                    Text(chargingSession.endTime, format: Date.FormatStyle(date: .abbreviated, time: .none))
                                    Spacer()
                                    if chargingSession.finalSOC != nil {
                                        Text(chargingSession.finalSOC!.formatted(.percent))
                                    }
                                    Spacer()
                                    Text(chargingSession.chargedEnergyFormatted)
                                }
                                HStack {
                                    Text(chargingSession.chargingCostPlan?.descriptionShortNoCar ?? "Unknown plan")
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                        }
                    }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Charging Sessions")
            }
            // New filter menu in the toolbar to replace the inline Picker
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { selectedCar = nil }) {
                        Text("All vehicles")
                    }
                    ForEach(vehicles, id: \.self) { car in
                        Button(action: { selectedCar = car }) {
                            Text(car.description)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(selectedCar == nil ? .primary : .blue)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: vehicles.isEmpty ? addCar : addSession) {
                    Image(systemName: "plus")
                }
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
    
    private func addSession() {
        if vehicles.isEmpty {
            activeAlert = .warning(message: "Please add a car first")
            showingAlert = true
            return
        }
        
        navigationPath.append(NavigationDestination.NewSession(selectedCar: selectedCar))
    }
    
    private func addCar() {
        navigationPath.append(CarsView.NavigationDestination.NewCar)
    }
}
