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
    
    @Binding var navigationPath: NavigationPath
    @State private var selectedCar: Car?
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var cars: [Car]
    @Query(sort: \Charger.name) private var chargers: [Charger]
    
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
                        .foregroundStyle(.gray)
                }
                Spacer()
                Picker("Car", selection: $selectedCar) {
                    Text("- all -").tag(nil as Car?)
                    ForEach(cars, id: \.self) { car in
                        Text(car.description).tag(car)
                    }
                }
            }.padding(.horizontal)
            
            ChargingSessionsList(navigationPath: $navigationPath, selectedCar: selectedCar)
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

    private func addCar() {
        navigationPath.append(CarsView.NavigationDestination.NewCar)
    }
}
