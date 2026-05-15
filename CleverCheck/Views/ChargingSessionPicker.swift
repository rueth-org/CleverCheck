//
//  ChargingSessionPicker.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 04/01/2026.
//

import SwiftUI
import SwiftData

struct ChargingSessionPicker: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isShowing: Bool
    var homeConsumption: HomeConsumption
    var showRefundedSessions: Bool
    var possibleSessions: [ChargingSession] {
        homeConsumption.possibleChargingSessions(ignoreConsumptionType: ignoreConsumptionType, modelContext: modelContext, showRefundedSessions: showRefundedSessions) ?? []
    }
    
    @State private var selectAll: Bool = false
    @State private var selectedSessions: Set<ChargingSession> = []
    @State var ignoreConsumptionType: Bool = false
    
    var body: some View {
        VStack {
            Text(showRefundedSessions ? "Refunded charging sessions" : "Select related charging sessions")
                .font(.headline)
                .padding()
            
            Button(action: {
                let sessionsToSave = Array(selectedSessions)
                let sessionsToRemove = Set(possibleSessions).subtracting(selectedSessions)
                
                for session in sessionsToSave {
                    session.relatedHomeConsumption = homeConsumption
                }
                
                for session in sessionsToRemove {
                    // If the session is assigned to another home consumption, leave it there, otherwise set to nil
                    if let relatedHomeConsumption = session.relatedHomeConsumption {
                        if relatedHomeConsumption.id == homeConsumption.id {
                            session.relatedHomeConsumption = nil
                        }
                    }
                }
                
                try? modelContext.save()
                
                // Close the sheet
                isShowing = false
            }) {
                Text("Save")
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
            
            Toggle("Ignore consumption type", isOn: $ignoreConsumptionType)
                .padding(.horizontal)
            Divider()
            
            Button(action: {
                selectAll.toggle()
                if selectAll {
                    selectedSessions = Set(possibleSessions)
                } else {
                    selectedSessions.removeAll()
                }
            }) {
                Image(systemName: selectAll ? "xmark.square" : "square")
                    .imageScale(.large)
                    .foregroundStyle(selectAll ? .green : .gray)
                Text("Select all")
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding()
            
            List(possibleSessions, id: \.id) { session in
                HStack {
                    Image(systemName: selectedSessions.contains(session) ? "xmark.square" : "square")
                        .imageScale(.large)
                        .foregroundStyle(selectedSessions.contains(session) ? .green : .gray)
                    Text(session.description)
                }
                .onTapGesture {
                    if selectedSessions.contains(session) {
                        selectedSessions.remove(session)
                    } else {
                        selectedSessions.insert(session)
                    }
                    if selectedSessions.count == possibleSessions.count {
                        selectAll = true
                    } else {
                        selectAll = false
                    }
                }
            }
        }
        .onAppear {
            if let preselectedSessions = showRefundedSessions ? homeConsumption.refundedChargingSessions : homeConsumption.chargingSessions {
                let possibleSessions = Set(possibleSessions)
                let commonSessions = possibleSessions.intersection(preselectedSessions)
                selectedSessions = commonSessions
            }
            
            if selectedSessions.count == possibleSessions.count {
                selectAll = true
            }
        }
    }
}

