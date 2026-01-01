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
    
    enum Resolution {
        case yearly
        case monthly
        case daily
        case session
    }
    
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    @State private var selectedCar: Car? = nil
    @State private var selectedResolution: Resolution = .monthly
    @State private var selectedDate: Date = Date.now.startDateOfMonth
    @State private var selectedSession: ChargingSession? = nil
    
    enum Screen {
        case charging, consumption
    }
    @State private var selectedScreen: Screen = .charging
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var vehicles: [Car]
    
    var chargingData: ChargingData? {
        if let selectedCar = selectedCar {
            var resolution: ChargingData.Resolution
            switch selectedResolution {
            case .session:
                resolution = .daily(date: selectedDate)
            case .daily:
                resolution = .daily(date: selectedDate)
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
    
    var dayPickerList: [Date] {
        var result = [Date]()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date(timeInterval: 0, since: selectedDate))!.count
        for i in 0..<daysInMonth {
            let day = i + 1
            result.append(DateComponents(calendar: calendar, year: year, month: month, day: day).date!)
        }
        return result
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if let chargingData = chargingData {
                    
                    // The date selection part
                    
                    Text(selectedCar?.description ?? "No car selected")
                        .font(Font.title.bold())
                    switch selectedResolution {
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
                    case .monthly:
                        HStack(alignment: .center) {
                            Button(action: decreaseMonth) {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Picker("Month", selection: $selectedDate) {
                                ForEach(monthPickerList, id: \.self) { date in
                                    Text(DateFormatter.displayAbbreviatedMonthOnly.string(from: date)).tag(date)
                                }
                            }
                            .labelsHidden()
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
                    case .daily:
                        HStack(alignment: .center) {
                            Button(action: decreaseDay) {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Picker("Day", selection: $selectedDate) {
                                ForEach(dayPickerList, id: \.self) { date in
                                    Text(DateFormatter.chartDisplayDateMonthly.string(from: date)).tag(date)
                                }
                            }
                            .labelsHidden()
                            Button(action: switchToMonthly) {
                                Text(DateFormatter.displayAbbreviatedMonthOnly.string(from: selectedDate))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            Button(action: switchToYearly) {
                                Text(verbatim: "\(Calendar.current.component(.year, from: selectedDate))")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button(action: increaseDay) {
                                Image(systemName: "chevron.right")
                            }
                            .buttonStyle(.plain)
                        }
                    case .session:
                        if let sessionToBeDisplayed = selectedSession {
                            // Determine the position of the session in all sessions of the day
                            let numberOfSessions = chargingData.chargingSessions.count
                            let sessionIndex = chargingData.chargingSessions.firstIndex(of: sessionToBeDisplayed)!
                            
                            // We are in sessions view
                            VStack {
                                HStack {
                                    Spacer()
                                    
                                    Text("Charging Session \(sessionIndex + 1) of \(numberOfSessions)")
                                        .font(.headline)
                                    
                                    Button(action: {
                                        withAnimation {
                                            selectedSession = nil
                                            selectedResolution = .daily
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.gray)
                                    
                                    Spacer()
                                }
                                HStack(alignment: .center) {
                                    Button(action: {
                                        if sessionIndex > 0 {
                                            selectedSession = chargingData.chargingSessions[sessionIndex - 1]
                                        }
                                    }) {
                                        Image(systemName: "chevron.left")
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(sessionIndex == 0)
                                    
                                    Spacer()
                                    
                                    Text(sessionToBeDisplayed.endTime.formatted(date: .abbreviated, time: .shortened))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        if sessionIndex < numberOfSessions - 1 {
                                            selectedSession = chargingData.chargingSessions[sessionIndex + 1]
                                        }
                                    }) {
                                        Image(systemName: "chevron.right")
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(sessionIndex == numberOfSessions - 1)
                                }
                            }
                        }
                    }
                    
                    // The data part
                    
                    if chargingData.chargingSessions.isEmpty {
                        HStack {
                            Spacer()
                            Text("No data")
                                .italic()
                                .foregroundStyle(Color.secondary)
                            Spacer()
                        }
                    } else {
                        if let sessionToBeDisplayed = selectedSession {
                            // Display the selected session
                            ChargingSessionDetails(session: sessionToBeDisplayed)
                        } else {
                            // The picker to choose which data to display
                            Picker("Choose data set", selection: $selectedScreen) {
                                Text("Charging data").tag(Screen.charging)
                                Text("Consumption").tag(Screen.consumption)
                            }
                            .pickerStyle(.palette)
                            
                            switch selectedScreen {
                            case .charging:
                                ChargingViewChart(chargingData: chargingData, onBarTap: { dateKey in
                                    let calendar = Calendar.current
                                    switch selectedResolution {
                                    case .yearly:
                                        // Switch to the month tapped and stored in dateKey as String (double-digit integer)
                                        let year = calendar.component(.year, from: selectedDate)
                                        let month = Int(dateKey) ?? calendar.component(.month, from: Date.now)
                                        if let newDate = DateComponents(
                                            calendar: calendar,
                                            year: year,
                                            month: month,
                                            day: 1
                                        ).date {
                                            withAnimation {
                                                selectedDate = newDate
                                                selectedResolution = .monthly
                                            }
                                        }
                                    case .monthly:
                                        // Switch to the day tapped and stored in dateKey as String (double-digit integer)
                                        let year = calendar.component(.year, from: selectedDate)
                                        let month = calendar.component(.month, from: selectedDate)
                                        let day = Int(dateKey) ?? calendar.component(.day, from: Date.now)
                                        if let newDate = DateComponents(
                                            calendar: calendar,
                                            year: year,
                                            month: month,
                                            day: day
                                        ).date {
                                            withAnimation {
                                                selectedDate = newDate
                                                selectedResolution = .daily
                                            }
                                        }
                                    case .daily:
                                        // Try to identify session
                                        if chargingData.chargingSessions.count == 1 {
                                            // There is only one session
                                            selectedSession = chargingData.chargingSessions.first!
                                        } else {
                                            // Create a date from the dateKey
                                            if let time = DateFormatter.chartDisplayDateDaily.date(from: dateKey) {
                                                let year = calendar.component(.year, from: selectedDate)
                                                let month = calendar.component(.month, from: selectedDate)
                                                let day = calendar.component(.day, from: selectedDate)
                                                
                                                // Add year, month and day to the time
                                                if let date = DateComponents(
                                                    calendar: calendar,
                                                    year: year,
                                                    month: month,
                                                    day: day,
                                                    hour: calendar.component(.hour, from: time),
                                                    minute: calendar.component(.minute, from: time)
                                                ).date {
                                                    // Try to match endTime
                                                    for session in chargingData.chargingSessions {
                                                        if session.endTime == date {
                                                            selectedSession = session
                                                            break
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        withAnimation {
                                            selectedResolution = .session
                                        }
                                    case .session:
                                        // Nothing to do here
                                        let _ = 0
                                    }
                                })
                                
                            case .consumption:
                                if let consumptionData = chargingData.consumptionData {
                                    ConsumptionChart(consumptionData: consumptionData)
                                } else {
                                    Text("Unable to load consumption data")
                                }
                            }
                            
                            // The summary data
                            ChargingViewSummary(chargingData: chargingData)
                        }
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
    
    private func decreaseDay() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        }
    }
    
    private func increaseDay() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
        }
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
        // Set correct date - we always need first of January of the year
        let year = Calendar.current.component(.year, from: selectedDate)
        let firstDayOfYear = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!
        self.selectedDate = firstDayOfYear
        withAnimation {
            self.selectedResolution = .yearly
        }
    }
    
    private func switchToMonthly() {
        // Set correct date - we always need the first day of the month
        let year = Calendar.current.component(.year, from: selectedDate)
        let month = Calendar.current.component(.month, from: selectedDate)
        let firstDayOfMonth = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
        self.selectedDate = firstDayOfMonth
        withAnimation {
            self.selectedResolution = .monthly
        }
    }
}
