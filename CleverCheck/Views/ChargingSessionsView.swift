//
//  ContentView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

struct ChargingSessionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @Query private var chargingSessions: [ChargingSession]

    var body: some View {
        List {
            ForEach(chargingSessions) { chargingSession in
                NavigationLink {
                    Text("Item at \(chargingSession.endTime, format: Date.FormatStyle(date: .numeric, time: .standard))")
                } label: {
                    Text(chargingSession.endTime, format: Date.FormatStyle(date: .numeric, time: .standard))
                }
            }
            .onDelete(perform: deleteSession)
        }
        .navigationDestination(for: ChargingSession.self) { chargingSession in
            ChargingSessionView(
                chargingSession: chargingSession,
                navigationPath: $navigationPath
            )
        }
        .toolbar {
            ToolbarItem {
                Button(action: addSession) {
                    Label("New Session", systemImage: "plus")
                }
            }
        }
    }
    
    private func addSession() {
        let chargingSession = ChargingSession.new()
        navigationPath.append(chargingSession)
    }

    private func deleteSession(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(chargingSessions[index])
            }
        }
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()
    ChargingSessionsView(navigationPath: $navigationPath)
        .modelContainer(for: ChargingSession.self, inMemory: true)
}
