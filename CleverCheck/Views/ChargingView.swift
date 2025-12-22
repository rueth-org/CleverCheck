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
    @State private var selectedResolution: Resolution = .monthly
    @State private var selectedDate: Date = Date.now.startDateOfMonth
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var vehicles: [Car]
    
    var chargingData: ChargingData? {
        if let selectedCar = selectedCar {
            var resolution: ChargingData.Resolution
            switch selectedResolution {
            case .monthly:
                resolution = .monthly(date: selectedDate)
            case .yearly:
                resolution = .yearly(date: selectedDate)
            }
            return try? ChargingData(modelContext: modelContext, vehicle: selectedCar, resolution: resolution)
        } else {
            return nil
        }
    }
    
    var monthPickerList: [Date] {
        var result = [Date]()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        for i in 0..<12 {
            let month = i + 1
            result.append(DateComponents(calendar: calendar, year: year, month: month, day: 1).date!)
        }
        return result
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if let chargingData = chargingData {
                    Text(selectedCar?.description ?? "No car selected")
                        .font(Font.title.bold())
                    switch selectedResolution {
                    case .monthly:
                        HStack(alignment: .center) {
                            Button(action: decreaseMonth) {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Picker("", selection: $selectedDate) {
                                ForEach(monthPickerList, id: \.self) { date in
                                    Text(DateFormatter.displayMonthOnly.string(from: date)).tag(date)
                                        .foregroundStyle(Color.primary)
                                }
                            }
                            Button(action: switchToYearly) {
                                Text(verbatim: "\(Calendar.current.component(.year, from: selectedDate))")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button(action: increaseMonth) {
                                Image(systemName: "chevron.right")
                            }
                            .buttonStyle(.plain)
                        }
                    case .yearly:
                        HStack(alignment: .center) {
                            Button(action: decreaseYear) {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button(action: switchToMonthly) {
                                Text(verbatim: "\(Calendar.current.component(.year, from: selectedDate))")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button(action: increaseYear) {
                                Image(systemName: "chevron.right")
                            }
                            .buttonStyle(.plain)
                        }
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
                } else {
                    Picker("Vehicle", selection: $selectedCar) {
                        Text("Select vehicle to show data").tag(nil as Car?)
                        ForEach(vehicles) { vehicle in
                            Text(vehicle.description).tag(vehicle)
                        }
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
            selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate)!
        }
    }
    
    private func increaseMonth() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate)!
        }
    }
    
    private func decreaseYear() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .year, value: -1, to: selectedDate)!
        }
    }
    
    private func increaseYear() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .year, value: 1, to: selectedDate)!
        }
    }
    
    private func switchToYearly() {
        self.selectedResolution = .yearly
    }
    
    private func switchToMonthly() {
        self.selectedResolution = .monthly
    }
}

extension DateFormatter {
    static let displayMonthly: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "MMMM yyyy"
         return formatter
    }()
    
    static let displayMonthOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()
}
