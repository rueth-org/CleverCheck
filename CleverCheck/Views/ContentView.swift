//
//  ContentView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

enum SimpleAlertType: Error {
    case success(message: LocalizedStringKey)
    case notice(message: LocalizedStringKey)
    case warning(message: LocalizedStringKey)
    case error(message: LocalizedStringKey)
    case fatalError(message: LocalizedStringKey)
    
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
    
    func message() -> Text {
        switch self {
        case let .success(message: message):
            return Text(message)
        case let .notice(message: message):
            return Text(message)
        case let .warning(message: message):
            return Text(message)
        case let .error(message: message):
            return Text(message)
        case let .fatalError(message: message):
            return Text(message) + Text(" - This should not have happened, please inform the developer team.")
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
        
    var body: some View {
        TabView {
            Tab("Charging", systemImage: "bolt.car") {
                ChargingView()
            }
            
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
    }
}
