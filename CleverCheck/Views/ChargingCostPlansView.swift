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
    
    @Query private var allPlans: [ChargingCostPlan]
    @Query private var chargingSessions: [ChargingSession]
    
    @State private var selectedPlan: ChargingCostPlan? = nil
    
    private var groupedPlans: [String: [ChargingCostPlan]] {
        Dictionary(grouping: allPlans) {
            if $0.car == nil {
                return "Unknown car"
            } else {
                return $0.car!.make + " " + $0.car!.model
            }
        }
    }
    
    var body: some View {
        VStack {
            if allPlans.isEmpty {
                Spacer()
                Image(systemName: "banknote")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No plans found.")
                Spacer()
            } else {
                List {
                    ForEach(groupedPlans.keys.sorted(), id: \.self) { carDescription in
                        Section(header: Text(carDescription)) {
                            ForEach(groupedPlans[carDescription]!, id: \.self) { chargingCostPlan in
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
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Charging Cost Plans")
            }
            ToolbarItem(placement: .topBarTrailing) {
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
