//
//  CarsView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 25/11/2025.
//

import SwiftUI
import SwiftData

struct ChargingCostPlansView: View {
    enum NavigationDestination: Hashable {
        case NewPlan(car: Car?)
        case EditPlan(plan: ChargingCostPlan)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    
    @Query private var chargingSessions: [ChargingSession]
    
    @State private var selectedPlan: ChargingCostPlan? = nil
    @State private var isShowingArchived: Bool = false
    
    var predicate: Predicate<ChargingCostPlan> {
        var predicate: Predicate<ChargingCostPlan>
        if !isShowingArchived {
            predicate = #Predicate<ChargingCostPlan> { plan in
                plan.isArchived == false
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
                groupBy: { plan in
                    if let car = plan.car {
                        return "\(car.make) \(car.model)"
                    } else {
                        return "Unknown car"
                    }
                },
                emptyStateMessage: "No plans found.",
                emptyStateSystemImage: "banknote"
            ) { chargingCostPlan in
                NavigationLink(value: NavigationDestination.EditPlan(plan: chargingCostPlan)) {
                    Text(chargingCostPlan.descriptionLongNoCar)
                }
                .swipeActions {
                    if canDelete(chargingCostPlan) {
                        Button(role: .destructive) {
                            deletePlan(chargingCostPlan)
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
                Text("Charging Cost Plans")
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
                Button(action: newPlan) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private func newPlan() {
        navigationPath.append(NavigationDestination.NewPlan(car: nil))
    }
    
    private func deletePlan(_ plan: ChargingCostPlan) {
        withAnimation {
            modelContext.delete(plan)
        }
        try? modelContext.save()
    }
    
    private func canDelete(_ plan: ChargingCostPlan) -> Bool {
        !chargingSessions.contains { $0.chargingCostPlan == plan }
    }
}
