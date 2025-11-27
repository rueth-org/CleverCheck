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
        case ChargingLocations
    }
    
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
        
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Button("Charging Sessions") {
                navigationPath.append(NavigationDestination.ChargingSessions)
            }
            Button("Cars") {
                navigationPath.append(NavigationDestination.Cars)
            }
            Button("Chargers") {
                navigationPath.append(NavigationDestination.Chargers)
            }
            Button("Charging Locations") {
                navigationPath.append(NavigationDestination.ChargingLocations)
            }
            Spacer()
            Button("Delete all data") {
                modelContext.container.deleteAllData()
            }
            .navigationDestination(for: NavigationDestination.self) { screen in
                switch screen {
                case .ChargingSessions:
                    ChargingSessionsView(navigationPath: $navigationPath)
                case .Cars:
                    CarsView(navigationPath: $navigationPath)
                case .Chargers:
                    ChargersView(navigationPath: $navigationPath)
                case .ChargingLocations:
                    ChargingLocationsView(navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: CarsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewCar:
                    CarView(navigationPath: $navigationPath, car: nil)
                case .EditCar(car: let car):
                    CarView(navigationPath: $navigationPath, car: car)
                }
            }
            .navigationDestination(for: ChargingLocationsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewLocation:
                    ChargingLocationEditor(navigationPath: $navigationPath, chargingLocation: nil)
                case .EditLocation(chargingLocation: let chargingLocation):
                    ChargingLocationEditor(navigationPath: $navigationPath, chargingLocation: chargingLocation)
                }
            }
            .navigationDestination(for: ChargingSessionsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewSession(car: let car):
                    ChargingSessionEditor(navigationPath: $navigationPath, chargingSession: nil, car: car)
                case .EditSession(chargingSession: let chargingSession, car: let car):
                    ChargingSessionEditor(navigationPath: $navigationPath, chargingSession: chargingSession, car: car)
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
        }
    }
}
