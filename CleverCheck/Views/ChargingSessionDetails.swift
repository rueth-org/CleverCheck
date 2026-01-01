//
//  ChargingSessionDetails.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/12/2025.
//

import SwiftUI

struct ChargingSessionDetails: View {
    @Binding var navigationPath: NavigationPath
    @Binding var selectedSession: ChargingSession?
    var vehicle: Car?
    var allSessions: [ChargingSession]
    
    var body: some View {
        if let session = selectedSession {
            List {
                // Determine the position of the session in all sessions of the day
                let numberOfSessions = allSessions.count
                let sessionIndex = allSessions.firstIndex(of: session)!
                
                // We are in sessions view
                VStack {
                    HStack {
                        Spacer()
                        
                        Text("Charging Session \(sessionIndex + 1) of \(numberOfSessions)")
                            .font(.headline)
                        
                        Spacer()
                    }
                    HStack(alignment: .center) {
                        Button(action: {
                            if sessionIndex > 0 {
                                selectedSession = allSessions[sessionIndex - 1]
                            }
                        }) {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        .disabled(sessionIndex == 0)
                        
                        Spacer()
                        
                        Text(session.endTime.formatted(date: .abbreviated, time: .shortened))
                        
                        Spacer()
                        
                        Button(action: {
                            if sessionIndex < numberOfSessions - 1 {
                                selectedSession = allSessions[sessionIndex + 1]
                            }
                        }) {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.plain)
                        .disabled(sessionIndex == numberOfSessions - 1)
                    }
                }
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
                if let specificCost = session.specificChargingCost {
                    Text("Cost per \(UserSettings.shared.energyUnitSymbol): \(specificCost.formatted())")
                }
                Text("Total cost: \(session.totalChargingCost.formatted())")
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
            .onTapGesture {
                selectedSession = nil
            }
            
            // The charging sessions button
            Button(action: {
                navigationPath.append(ChargingSessionsView.NavigationDestination.EditSession(chargingSession: session, selectedCar: vehicle))
                selectedSession = nil
            }) {
                Text("Edit")
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
        } else {
            Text("No session selected")
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
