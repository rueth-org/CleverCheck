//
//  ContentView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

enum SimpleAlertType: Error {
    case success(message: String)
    case notice(message: String)
    case warning(message: String)
    case error(message: String)
    case fatalError(message: String)
    
    func title() -> String {
        switch self {
        case .success(_):
            return NSLocalizedString("Success", comment: "")
        case .notice(_):
            return NSLocalizedString("Notice", comment: "")
        case .warning(_):
            return NSLocalizedString("Warning", comment: "")
        case .error(_):
            return NSLocalizedString("Error", comment: "")
        case .fatalError(_):
            return NSLocalizedString("Fatal Error", comment: "")
        }
    }
    
    func button() -> some View {
        Button("OK", role: .cancel) {}
    }
    
    func message() -> some View {
        Text(verbatim: messageAsString())
    }
    
    func messageAsString() -> String {
        switch self {
        case let .success(message: message):
            return NSLocalizedString(message, comment: "")
        case let .notice(message: message):
            return NSLocalizedString(message, comment: "")
        case let .warning(message: message):
            return NSLocalizedString(message, comment: "")
        case let .error(message: message):
            return NSLocalizedString(message, comment: "")
        case let .fatalError(message: message):
            return "\(NSLocalizedString(message, comment: "")) - \(NSLocalizedString("This should not have happened, please inform the developer team.", comment: ""))"
        }
    }
}

struct ContentView: View {
    enum NavigationDestination: Hashable {
        case ChargingSessions
        case Cars
        case Chargers
        case Locations
        case ChargingCostPlans
        case HomeConsumptions
    }
    
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
        
    var body: some View {
        NavigationStack(path: $navigationPath) {
            TabView {
                Tab("Charging", systemImage: "bolt.car") {
                    ChargingView(navigationPath: $navigationPath)
                }
                
                Tab("Home", systemImage: "house") {
                    HomeView(navigationPath: $navigationPath)
                }
                
                Tab("Settings", systemImage: "gear") {
                    SettingsView(navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: NavigationDestination.self) { screen in
                switch screen {
                case .ChargingSessions:
                    ChargingSessionsView(navigationPath: $navigationPath)
                case .Cars:
                    CarsView(navigationPath: $navigationPath)
                case .Chargers:
                    ChargersView(navigationPath: $navigationPath)
                case .Locations:
                    LocationsView(navigationPath: $navigationPath)
                case .ChargingCostPlans:
                    ChargingCostPlansView(navigationPath: $navigationPath)
                case .HomeConsumptions:
                    HomeConsumptionsView(navigationPath: $navigationPath)
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
            .navigationDestination(for: LocationsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewLocation:
                    LocationEditor(navigationPath: $navigationPath, location: nil)
                case .EditLocation(location: let location):
                    LocationEditor(navigationPath: $navigationPath, location: location)
                }
            }
            .navigationDestination(for: ChargingSessionsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewSession(car: let car):
                    ChargingSessionEditor(navigationPath: $navigationPath, chargingSession: nil, car: car)
                case .EditSession(chargingSession: let chargingSession):
                    ChargingSessionEditor(navigationPath: $navigationPath, chargingSession: chargingSession)
                }
            }
            .navigationDestination(for: ChargersView.NavigationDestination.self) { screen in
                switch screen {
                case .NewCharger:
                    ChargerEditor(navigationPath: $navigationPath, charger: nil)
                case .EditCharger(charger: let charger):
                    ChargerEditor(navigationPath: $navigationPath, charger: charger)
                }
            }
            .navigationDestination(for: ChargingCostPlansView.NavigationDestination.self) { screen in
                switch screen {
                case .NewPlan:
                    ChargingCostPlanEditor(navigationPath: $navigationPath, plan: nil)
                case .EditPlan(plan: let plan):
                    ChargingCostPlanEditor(navigationPath: $navigationPath, plan: plan)
                }
            }
            .navigationDestination(for: HomeConsumptionsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewConsumption:
                    let newHomeConsumption = HomeConsumption(
                        name: "",
                        validFrom: Date.now.startDateOfMonth,
                        validUntil: Date.now.endDateOfMonth,
                        consumption: .init(value: 0.0, unit: .kilowattHours),
                        consumptionIncludedElsewhere: false,
                        associatedLocation: nil
                    )
                    HomeConsumptionEditor(navigationPath: $navigationPath, homeConsumption: newHomeConsumption, isNew: true)
                case .EditConsumption(homeConsumption: let HomeConsumption):
                    HomeConsumptionEditor(navigationPath: $navigationPath, homeConsumption: HomeConsumption, isNew: false)
                }
            }
        }
    }
}
