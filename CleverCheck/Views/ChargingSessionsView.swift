//
//  ContentView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

struct ChargingSessionsView: View {
    @Binding var navigationPath: NavigationPath
    @State private var selectedCar: Car?
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var cars: [Car]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    var body: some View {
        VStack {
            HStack {
                Text("Car")
                Button {
                    addCar()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.green)
                }
                Spacer()
                Picker("Car", selection: $selectedCar) {
                    Text("- all -").tag(nil as Car?)
                    ForEach(cars, id: \.self) { car in
                        Text("\(car.make) \(car.model)").tag(car)
                    }
                }
            }.padding(.horizontal)
            
            ChargingSessionsList(navigationPath: $navigationPath, selectedCar: selectedCar)
        }
        .navigationTitle(Text("Charging Sessions"))
        .navigationDestination(for: ChargingSession.self) { chargingSession in
            ChargingSessionView(
                chargingSession: chargingSession,
                navigationPath: $navigationPath
            )
        }
        .toolbar {
            ToolbarItem {
                Button(action: addSession) {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.green)
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

    private func addCar() {
        navigationPath.append(CarsView.NavigationDestination.NewCar)
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()
    ChargingSessionsView(navigationPath: $navigationPath)
        .modelContainer(for: ChargingSession.self, inMemory: true)
}
