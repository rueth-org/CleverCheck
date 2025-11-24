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
        case NewCar
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @State private var selectedCar: Car?
    @Query private var cars: [Car]
    @Query private var chargingSessions: [ChargingSession]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?

    var body: some View {
        HStack {
            Text("Car")
            Spacer()
            Picker("Car", selection: $selectedCar) {
                Text("- all -").tag(nil as Car?)
                ForEach(cars) { car in
                    Text(car.make + " " + car.model).tag(car)
                }
            }
            Button {
                addCar()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.green)
            }
        }.padding()
        
        List {
            ForEach(chargingSessions) { chargingSession in
                VStack {
                    HStack {
                        Text(chargingSession.endTime, format: Date.FormatStyle(date: .abbreviated, time: .none))
                        Spacer()
                        Text(chargingSession.amount.formatted())
                        Text("kWh")
                    }
                    HStack {
                        Text("\(chargingSession.car.make) \(chargingSession.car.model)")
                        Spacer()
                        if chargingSession.finalSOC != nil {
                            Text(chargingSession.finalSOC!.formatted(.percent))
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    // Edit
                    Button("Edit", systemImage: "pencil") {
                        navigationPath.append(chargingSession)
                    }
                    .tint(.blue)
                    
                    // Delete
                    Button("Delete", systemImage: "trash") {
                        deleteSession(chargingSession: chargingSession)
                    }
                    .tint(.red)
                }
            }
        }
        .navigationDestination(for: ChargingSession.self) { chargingSession in
            ChargingSessionView(
                chargingSession: chargingSession,
                navigationPath: $navigationPath
            )
        }
        .navigationDestination(for: NavigationDestination.self) { screen in
            switch screen {
            case .NewCar:
                CarView(navigationPath: $navigationPath)
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: addSession) {
                    Label("New Session", systemImage: "plus")
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
        if cars.isEmpty {
            activeAlert = .warning(message: "Please add a car first")
            showingAlert = true
        } else if selectedCar == nil {
            activeAlert = .warning(message: "Please select a car first")
            showingAlert = true
        } else {
            let chargingSession = ChargingSession(
                endTime: Date.now,
                amount: 0.0,
                car: selectedCar!
            )
            navigationPath.append(chargingSession)
        }
    }

    private func deleteSession(chargingSession: ChargingSession) {
        withAnimation {
            modelContext.delete(chargingSession)
        }
    }
    
    private func addCar() {
        navigationPath.append(NavigationDestination.NewCar)
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()
    ChargingSessionsView(navigationPath: $navigationPath)
        .modelContainer(for: ChargingSession.self, inMemory: true)
}
