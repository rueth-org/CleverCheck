//
//  CarsView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 25/11/2025.
//

import SwiftUI
import SwiftData

struct ChargersView: View {
    enum NavigationDestination: Hashable {
        case NewCharger
        case EditCharger(charger: Charger)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @Query(sort: \Charger.name) private var chargers: [Charger]
    @Query private var chargingCostPlans: [ChargingCostPlan]
    @State private var selectedCharger: Charger? = nil
    
    private var groupedChargers: [String: [Charger]] {
        Dictionary(grouping: chargers) { $0.location?.name ?? NSLocalizedString("No location", comment: "") }
    }
    
    var body: some View {
        VStack {
            if chargers.isEmpty {
                Spacer()
                Image(systemName: "ev.charger")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No chargers found.")
                Spacer()
            } else {
                List {
                    ForEach(groupedChargers.keys.sorted(), id: \.self) { location in
                        Section(header: Text(location)) {
                            ForEach(groupedChargers[location]!, id: \.self) { charger in
                                NavigationLink(value: NavigationDestination.EditCharger(charger: charger)) {
                                    Text(charger.name)
                                }
                                .swipeActions {
                                    if canDelete(charger) {
                                        Button(role: .destructive) {
                                            deleteCharger(charger)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    } else {
                                        Button(role: .destructive) {
                                            // no action
                                        } label: {
                                            Label("Cannot delete", systemImage: "trash")
                                        }
                                        .tint(.secondary)
                                        .disabled(true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Chargers")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: newCharger) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private func newCharger() {
        navigationPath.append(NavigationDestination.NewCharger)
    }
    
    private func deleteCharger(_ charger: Charger) {
        withAnimation {
            modelContext.delete(charger)
        }
        try? modelContext.save()
    }
    
    private func canDelete(_ charger: Charger) -> Bool {
        !chargingCostPlans.contains { $0.charger == charger }
    }
}
