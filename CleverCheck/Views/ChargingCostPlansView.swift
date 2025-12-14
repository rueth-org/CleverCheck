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
        case NewPlan
        case EditPlan(plan: ChargingCostPlan)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    
    @Query private var allPlans: [ChargingCostPlan]
    
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
                                    Text(NSLocalizedString(chargingCostPlan.descriptionLongNoCar, comment: ""))
                                }
                            }
                            .onDelete { offsets in
                                // Map offsets to the correct indices in allPlans
                                let allPlansForCar = groupedPlans[carDescription]!
                                let indicesToDelete = offsets.map { index in
                                    allPlans.firstIndex(of: allPlansForCar[index])!
                                }
                                deletePlan(at: IndexSet(indicesToDelete))
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button(action: newPlan) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private func newPlan() {
        navigationPath.append(NavigationDestination.NewPlan)
    }
    
    private func deletePlan(at offsets: IndexSet) {
        // TODO check if can be deleted
        for offset in offsets {
            // Find plan in our query
            let plan = allPlans[offset]

            // Delete it from the context
            withAnimation {
                modelContext.delete(plan)
            }
        }
    }
}
