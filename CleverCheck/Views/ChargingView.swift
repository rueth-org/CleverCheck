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
    
    enum Resolution: LocalizedStringKey {
        case yearly = "yearly"
        case monthly = "monthly"
    }
    
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    @State private var selectedCar: Car? = nil
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedResolution: Resolution = .monthly
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var vehicles: [Car]
    
    var chargingData: ChargingData? {
        if let selectedCar = selectedCar {
            var resolution: ChargingData.Resolution
            switch selectedResolution {
            case .monthly:
                resolution = .monthly(year: selectedYear, month: selectedMonth)
            case .yearly:
                resolution = .yearly(year: selectedYear)
            }
            return try? ChargingData(modelContext: modelContext, vehicle: selectedCar, resolution: resolution)
        } else {
            return nil
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if let chargingData = chargingData {
                    switch selectedResolution {
                    case .monthly:
                        let date = Date().startDateOf(month: selectedMonth, year: selectedYear)
                        HStack {
                            Button(action: decreaseMonth) {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Text(DateFormatter.displayMonthly.string(from: date))
                            Spacer()
                            Button(action: increaseMonth) {
                                Image(systemName: "chevron.right")
                            }
                            .buttonStyle(.plain)
                        }
                    case .yearly:
                        Text("\(selectedYear)")
                    }
                    
                    if chargingData.chargingSessions.isEmpty {
                        HStack {
                            Spacer()
                            Text("No data")
                                .italic()
                                .foregroundStyle(Color.secondary)
                            Spacer()
                        }
                    } else {
                        ChargingViewChart(chargingData: chargingData)
                    }
                }
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
                    ChargingSessionsView(navigationPath: $navigationPath, selectedCar: $selectedCar)
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
    }
    
    private func addSession() {
        navigationPath.append(ChargingSessionsView.NavigationDestination.NewSession(selectedCar: selectedCar))
    }
    
    private func addCar() {
        navigationPath.append(CarsView.NavigationDestination.NewCar)
    }
    
    private func decreaseMonth() {
        withAnimation {
            if selectedMonth == 1 {
                selectedMonth = 12
                selectedYear -= 1
            } else {
                selectedMonth -= 1
            }
        }
    }
    
    private func increaseMonth() {
        withAnimation {
            if selectedMonth == 12 {
                selectedMonth = 1
                selectedYear += 1
            } else {
                selectedMonth += 1
            }
        }
    }
}

extension DateFormatter {
    static let displayMonthly: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "MMMM yyyy"
         return formatter
    }()
}
