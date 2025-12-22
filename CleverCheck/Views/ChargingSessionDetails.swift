//
//  ChargingSessionDetails.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/12/2025.
//

import SwiftUI

struct ChargingSessionDetails: View {
    var session: ChargingSession
    
    var body: some View {
        if let startTime = session.startTime {
            Text("Session started: \(startTime.formatted(date: .abbreviated, time: .shortened))")
        }
        Text("Session ended: \(session.endTime.formatted(date: .abbreviated, time: .shortened))")
        if let startTime = session.startTime {
            let duration = session.endTime.timeIntervalSince(startTime)
            let durationString = DateComponentsFormatter.hoursAndMinutes.string(from: duration) ?? "–"
            Text("Duration: \(durationString)")
        }
        Text("Charged energy: \(session.chargedEnergy.formatted())")
        if let chargingCost = session.chargingCost {
            Text("Cost: \(chargingCost.formatted())")
        }
        if let mileage = session.mileage {
            Text("Mileage: \(mileage.formatted())")
        }
        if let initialSOC = session.initialSOC, let finalSOC = session.finalSOC {
            Text("SOC: \(initialSOC.formatted(.percent)) → \(finalSOC.formatted(.percent))")
        } else if let initialSOC = session.initialSOC {
            Text("Initial SOC: \(initialSOC.formatted(.percent))")
        } else if let finalSOC = session.finalSOC {
            Text("Final SOC: \(finalSOC.formatted(.percent))")
        }
        if let comment = session.comment, !comment.isEmpty {
            Text("Comment: \(comment)")
        }
    }
}

extension DateComponentsFormatter {
    static var hoursAndMinutes: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()
}
