//
//  SimpleAlert.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 13/01/2026.
//

import Foundation
import SwiftUI

// Protocol used by views that present alerts. Returns AnyView for the actions so the protocol can be used as an existential.
protocol AlertPresentable {
    func title() -> String
    func message() -> Text
    func actionButtons() -> AnyView
}

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
    
    // New: return a wrapper that carries custom buttons instead of trying to stash them using object identity
    func withButtons(_ buttons: [SimpleAlertButton]) -> SimpleAlert {
        return SimpleAlert(type: self, customButtons: buttons)
    }
    
    // Keep a simple default button view for cases where no custom buttons are attached
    func button() -> some View {
        return AnyView(Button("OK", role: .cancel) {})
    }
}

extension SimpleAlertType: AlertPresentable {
    func actionButtons() -> AnyView {
        AnyView(self.button())
    }
}

struct SimpleAlertButton: Identifiable {
    let id = UUID()
    let title: String
    let role: ButtonRole?
    let action: (() -> Void)?
}

// Remove the fragile global customButtonsStorage; the wrapper stores buttons per-alert instance instead.
// private var customButtonsStorage = [ObjectIdentifier: [SimpleAlertButton]]()

// Thin wrapper that carries the enum value plus optional custom buttons and a stable UUID identity.
struct SimpleAlert: Error, Identifiable {
    let id: UUID
    let type: SimpleAlertType
    let customButtons: [SimpleAlertButton]?
    
    init(type: SimpleAlertType, customButtons: [SimpleAlertButton]? = nil) {
        self.id = UUID()
        self.type = type
        self.customButtons = customButtons
    }
    
    func title() -> String { type.title() }
    func message() -> Text { type.message() }
    
    // Convert our SimpleAlertButton descriptor into SwiftUI Alert.Button
    private static func alertButton(from btn: SimpleAlertButton) -> Alert.Button {
        let action = btn.action
        switch btn.role {
        case .destructive:
            return .destructive(Text(btn.title), action: action)
        case .cancel:
            return .cancel(Text(btn.title), action: action)
        default:
            return .default(Text(btn.title), action: action)
        }
    }
    
    // Build an Alert using up to two custom buttons (Alert supports either one dismissButton or two primary/secondary)
    func makeAlert() -> Alert {
        if let buttons = customButtons, !buttons.isEmpty {
            if buttons.count == 1 {
                return Alert(title: Text(title()), message: message(), dismissButton: SimpleAlert.alertButton(from: buttons[0]))
            } else {
                let primary = SimpleAlert.alertButton(from: buttons[0])
                let secondary = SimpleAlert.alertButton(from: buttons[1])
                return Alert(title: Text(title()), message: message(), primaryButton: primary, secondaryButton: secondary)
            }
        } else {
            return Alert(title: Text(title()), message: message(), dismissButton: .cancel(Text("OK")))
        }
    }
    
    // Provide actions as AnyView so the protocol can be used as an existential in presenting APIs.
    func actionButtons() -> AnyView {
        if let buttons = customButtons, !buttons.isEmpty {
            return AnyView(ForEach(buttons) { btn in
                Button(btn.title, role: btn.role, action: btn.action ?? {})
            })
        } else {
            return AnyView(type.button())
        }
    }
}
