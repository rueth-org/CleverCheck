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
        case NewSession(car: Car?)
        case EditSession(chargingSession: ChargingSession)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @State private var selectedCar: Car?
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var cars: [Car]
    @Query(sort: \Charger.name) private var chargers: [Charger]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    var predicate: Predicate<ChargingSession> {
        var predicate: Predicate<ChargingSession>
        if let id = selectedCar?.persistentModelID {
            predicate = #Predicate<ChargingSession> { chargingSession in
                chargingSession.car?.persistentModelID == id
            }
        } else {
            predicate = .true
        }
        return predicate
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Car")
                Button {
                    addCar()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.gray)
                }
                Spacer()
                Picker("Car", selection: $selectedCar) {
                    Text("All vehicles").tag(nil as Car?)
                    ForEach(cars, id: \.self) { car in
                        Text(car.description).tag(car)
                    }
                }
            }.padding()
            
            // List of charging sessions
            DynamicList(
                predicate: predicate,
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
                    NavigationLink(value: ChargingSessionsView.NavigationDestination.EditSession(chargingSession: chargingSession)) {
                        VStack {
                            HStack {
                                Text(chargingSession.endTime, format: Date.FormatStyle(date: .abbreviated, time: .none))
                                Spacer()
                                Text(chargingSession.chargedEnergyKWh.formatted())
                                Text("kWh")
                            }
                            HStack {
                                Text(chargingSession.car?.description ?? "- unknown -")
                                Spacer()
                                if chargingSession.finalSOC != nil {
                                    Text(chargingSession.finalSOC!.formatted(.percent))
                                }
                            }
                        }
                    }
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Charging Sessions")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button(action: addSession) {
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
        if cars.isEmpty || chargers.isEmpty {
            activeAlert = .warning(message: "Please add a car and a charger first")
            showingAlert = true
        } else {
            navigationPath.append(NavigationDestination.NewSession(car: selectedCar))
        }
    }
    
    /*
    private func deleteSession(at offsets: IndexSet) {
        // TODO check if can be deleted
        for offset in offsets {
            // Find location in our query
            let session = chargingSessions[offset]

            // Delete it from the context
            withAnimation {
                modelContext.delete(session)
            }
        }
    }*/

    private func addCar() {
        navigationPath.append(CarsView.NavigationDestination.NewCar)
    }
}
