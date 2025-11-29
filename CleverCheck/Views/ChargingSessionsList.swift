//
//  ChargingSessionsList.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 25/11/2025.
//

import SwiftUI
import SwiftData

struct ChargingSessionsList: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @Query private var chargingSessions: [ChargingSession]
    
    var body: some View {
        if chargingSessions.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No charging sessions found.")
                Spacer()
            }
            Spacer()
        } else {
            List {
                ForEach(chargingSessions) { chargingSession in
                    NavigationLink(value: ChargingSessionsView.NavigationDestination.EditSession(chargingSession: chargingSession)) {
                        VStack {
                            HStack {
                                Text(chargingSession.endTime, format: Date.FormatStyle(date: .abbreviated, time: .none))
                                Spacer()
                                Text(chargingSession.amount.formatted())
                                Text("kWh")
                            }
                            HStack {
                                Text(chargingSession.car.description)
                                Spacer()
                                if chargingSession.finalSOC != nil {
                                    Text(chargingSession.finalSOC!.formatted(.percent))
                                }
                            }
                        }
                    }
                }
                .onDelete(perform: deleteSession)
            }
        }
    }
    
    init(navigationPath: Binding<NavigationPath>, selectedCar: Car?) {
        self._navigationPath = navigationPath
        
        var predicate: Predicate<ChargingSession>
        if let id = selectedCar?.persistentModelID {
            predicate = #Predicate<ChargingSession> { chargingSession in
                chargingSession.car.persistentModelID == id
            }
        } else {
            predicate = .true
        }
        
        _chargingSessions = Query(filter: predicate, sort: \ChargingSession.endTime)
    }
    
    private func deleteSession(at offsets: IndexSet) {
        // TODO check if can be deleted
        for offset in offsets {
            // Find location in our query
            let session = chargingSessions[offset]

            // Delete it from the context
            withAnimation {
                modelContext.delete(session)
            }
        }
    }
}
