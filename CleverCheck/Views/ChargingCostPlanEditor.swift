//
//  ChargingCostPlanEditor.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 29/11/2025.
//

import SwiftUI
import SwiftData

struct ChargingCostPlanEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    
    let plan: ChargingCostPlan?
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var cars: [Car]
    @Query(sort: \Charger.name) private var chargers: [Charger]
    
    @State private var car: Car?
    @State private var charger: Charger?
    
    @State private var planType: ChargingCostPlan.PlanType?
    @State private var selectedPlanType: String?
    
    private let planTypes = [
        ChargingCostPlan.PlanType.descriptionIndividual,
        ChargingCostPlan.PlanType.descriptionFlatrate,
        ChargingCostPlan.PlanType.descriptionRefunded
    ]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    private var editorTitle: String {
        plan == nil ? "New Plan" : "Edit Plan"
    }
    
    var body: some View {
        Form {
            // Car
            Picker("Car", selection: $car) {
                Text("- Select a car -").tag(nil as Car?)
                ForEach(cars) { car in
                    Text("\(car.make) \(car.model)").tag(car)
                }
            }
            
            // Charger
            Picker("Charger", selection: $charger) {
                Text("- Select a charger -").tag(nil as Charger?)
                ForEach(chargers) { charger in
                    Text("\(charger.description)").tag(charger)
                }
            }
            
            // Charging Cost Plan
            Picker("Plan Type", selection: $selectedPlanType) {
                ForEach(planTypes, id: \.self) { planType in
                    Text(planType).tag(planType)
                }
            }
            .pickerStyle(.segmented)
            
            planDataView()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(editorTitle)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    withAnimation {
                        saveAndExit()
                    }
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) {
                    cancelAndExit()
                }
            }
        }
        .onAppear {
            if let plan {
                // Edit the incoming car.
                car = plan.car
                charger = plan.charger
                planType = plan.planType
            }
        }
        .alert(
            activeAlert?.title() ?? "Notice",
            isPresented: $showingAlert,
            presenting: activeAlert
        ) { activeAlert in
            activeAlert.button()
        } message: { activeAlert in
            activeAlert.message()
        }
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        // Data check: No car selected
        if car == nil {
            activeAlert = .error(message: "Please select a car.")
            showingAlert = true
            return
        }
        
        // Data check: No charger selected
        if charger == nil {
            activeAlert = .error(message: "Please select a charger.")
            showingAlert = true
            return
        }
        
        // Data check: No plan selected
        if planType == nil {
            activeAlert = .error(message: "Please select a plan type.")
            showingAlert = true
            return
        }
        
        if let plan {
            // Edit the car
            plan.car = car!
            plan.charger = charger!
            plan.planType = planType!
        } else {
            let newPlan = ChargingCostPlan(car: car!, charger: charger!, planType: planType!)
            modelContext.insert(newPlan)
        }
        
        // Leave editor
        navigationPath.removeLast()
    }
    
    @ViewBuilder
    private func planDataView() -> some View {
        switch selectedPlanType {
        case ChargingCostPlan.PlanType.descriptionIndividual:
            Text("Individual")
        case ChargingCostPlan.PlanType.descriptionFlatrate:
            Text("Flatrate")
        case ChargingCostPlan.PlanType.descriptionRefunded:
            Text("Refunded")
        case .none:
            EmptyView()
        case .some(_):
            EmptyView()
        }
    }
}
