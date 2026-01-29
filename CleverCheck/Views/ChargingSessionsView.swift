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
    @Binding var selectedCar: Car?
    
    @State var timeBox: TimeBox
    
    @Query private var vehicles: [Car]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?
    
    private var groupedSessions: [String: [ChargingSession]] {
        var result: [String: [ChargingSession]] = [:]
        if selectedCar == nil {
            // Display all vehicles
            for vehicle in vehicles {
                var chargingSessions: [ChargingSession] = []
                if let chargingCostPlans = vehicle.chargingCostPlans {
                    for chargingCostPlan in chargingCostPlans {
                        chargingSessions.append(contentsOf: chargingCostPlan.chargingSessions?.filter { session in
                            if let period = timeBox.timePeriod {
                                return period.start <= session.endTime && session.endTime <= period.end
                            } else {
                                return true
                            }
                        } ?? [])
                    }
                    result[vehicle.description] = chargingSessions.sorted(by: { $0.endTime > $1.endTime })
                }
            }
        } else {
            // Display only the selected vehicle
            var chargingSessions: [ChargingSession] = []
            if let chargingCostPlans = selectedCar?.chargingCostPlans {
                for chargingCostPlan in chargingCostPlans {
                    chargingSessions.append(contentsOf: chargingCostPlan.chargingSessions?.filter { session in
                        if let period = timeBox.timePeriod {
                            return period.start <= session.endTime && session.endTime <= period.end
                        } else {
                            return true
                        }
                    } ?? [])
                }
                result[selectedCar!.description] = chargingSessions.sorted(by: { $0.endTime > $1.endTime })
            }
        }
        return result
    }
    
    var body: some View {
        VStack {
            TimeBoxPicker(timeBox: timeBox)
                .padding(.horizontal)
        }
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
                    ForEach(groupedSessions[carDescription]!.sorted(by: { $0 > $1 }), id: \.self) { chargingSession in
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
                                    let totalChargingCost = chargingSession.totalChargingCost
                                    if totalChargingCost.amount > 0 {
                                        Text(totalChargingCost.converted(to: UserSettings.shared.currencyIdentifier)?.formatted() ?? "")
                                            .italic()
                                    }
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
                    MenuCarSelector(selectedCar: $selectedCar, allCars: vehicles)
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
            activeAlert.actionButtons()
        } message: { activeAlert in
            activeAlert.message()
        }
    }
    
    init(
        navigationPath: Binding<NavigationPath>,
        selectedCar: Binding<Car?>,
        timeBox: TimeBox
    ) {
        self._navigationPath = navigationPath
        self._selectedCar = selectedCar
        self._timeBox = State(initialValue: timeBox)
        
        let predicate = #Predicate<Car> { car in
            car.isArchived == false
        }
        
        _vehicles = Query(
            filter: predicate,
            sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]
        )
    }
    
    private func addSession() {
        if vehicles.isEmpty {
            activeAlert = SimpleAlert(type: .warning(message: "Please add a car first"))
            showingAlert = true
            return
        }
        
        navigationPath.append(NavigationDestination.NewSession(selectedCar: selectedCar))
    }
    
    private func addCar() {
        navigationPath.append(CarsView.NavigationDestination.NewCar)
    }
    
    private func delete(for session: ChargingSession) {
        // Delete it from the context
        withAnimation {
            modelContext.delete(session)
        }
        try? modelContext.save()
    }
}
