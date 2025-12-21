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
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var vehicles: [Car]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    private var groupedSessions: [String: [ChargingSession]] {
        var result: [String: [ChargingSession]] = [:]
        let selectedCarID = UserSettings.shared.selectedCarID
        let currentSelectedCar = selectedCarID.isEmpty ? nil : vehicles.first(where: { $0.id.uuidString == selectedCarID })
        if currentSelectedCar == nil {
            // Display all vehicles
            for vehicle in vehicles {
                var chargingSessions: [ChargingSession] = []
                if let chargingCostPlans = vehicle.chargingCostPlans {
                    for chargingCostPlan in chargingCostPlans {
                        chargingSessions.append(contentsOf: chargingCostPlan.chargingSessions ?? [])
                    }
                    result[vehicle.description] = chargingSessions.sorted(by: { $0.endTime > $1.endTime })
                }
            }
        } else {
            // Display only the selected vehicle
            var chargingSessions: [ChargingSession] = []
            if let chargingCostPlans = currentSelectedCar?.chargingCostPlans {
                for chargingCostPlan in chargingCostPlans {
                    chargingSessions.append(contentsOf: chargingCostPlan.chargingSessions ?? [])
                }
                result[currentSelectedCar!.description] = chargingSessions.sorted(by: { $0.endTime > $1.endTime })
            }
        }
        return result
    }
    
    var body: some View {
        List(groupedSessions.keys.sorted(), id: \.self) { carDescription in
            Section(header: Text(carDescription)) {
                if groupedSessions[carDescription]!.isEmpty {
                    HStack {
                        Spacer()
                        Image(systemName: "bolt.fill")
                        Text(.noChargingSessionsFound)
                        Spacer()
                    }
                    .foregroundColor(.gray)
                } else {
                    ForEach(groupedSessions[carDescription]!, id: \.self) { chargingSession in
                        NavigationLink(value: ChargingSessionsView.NavigationDestination.EditSession(chargingSession: chargingSession, selectedCar: chargingSession.chargingCostPlan?.car)) {
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
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(for: chargingSession)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Charging Sessions")
            }
            // New filter menu in the toolbar to replace the inline Picker
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { UserSettings.shared.selectedCarID = "" }) {
                        Text("All vehicles")
                    }
                    ForEach(vehicles, id: \.self) { car in
                        Button(action: { UserSettings.shared.selectedCarID = car.id.uuidString }) {
                            Text(car.description)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(UserSettings.shared.selectedCarID.isEmpty ? .primary : .blue)
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
        
        let selectedCarID = UserSettings.shared.selectedCarID
        let currentSelectedCar = selectedCarID.isEmpty ? nil : vehicles.first(where: { $0.id.uuidString == selectedCarID })
        navigationPath.append(NavigationDestination.NewSession(selectedCar: currentSelectedCar))
    }
    
    private func addCar() {
        navigationPath.append(CarsView.NavigationDestination.NewCar)
    }
    
    private func delete(for session: ChargingSession) {
        // Delete it from the context
        withAnimation {
            modelContext.delete(session)
        }
    }
}
