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
    
    @Query(filter: #Predicate<ChargingCostPlan> { plan in
        plan.isArchived == false
    }) private var chargingCostPlans: [ChargingCostPlan]
    
    @State private var selectedCharger: Charger? = nil
    @State private var isShowingArchived: Bool = false
    
    var predicate: Predicate<Charger> {
        var predicate: Predicate<Charger>
        if !isShowingArchived {
            predicate = #Predicate<Charger> { charger in
                charger.isArchived == false
            }
        } else {
            predicate = .true
        }
        return predicate
    }
    
    var body: some View {
        List {
            DynamicList(
                predicate: predicate,
                sorting: [SortDescriptor(\Charger.name)],
                groupBy: { charger in
                    charger.location?.name ?? NSLocalizedString("No location", comment: "")
                },
                emptyStateMessage: "No chargers found.",
                emptyStateSystemImage: "ev.charger"
            ) { charger in
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Chargers")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: {
                    withAnimation {
                        isShowingArchived.toggle()
                    }
                }) {
                    Image(systemName: isShowingArchived ? "archivebox.circle.fill" : "archivebox.circle")
                        .foregroundStyle(isShowingArchived ? .blue : .primary)
                }
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

