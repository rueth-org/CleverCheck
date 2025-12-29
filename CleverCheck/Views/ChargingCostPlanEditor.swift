//
//  ChargingCostPlanEditor.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 29/11/2025.
//

import SwiftUI
import SwiftData

struct ChargingCostPlanEditor: View {
    private enum Field: Int, Hashable {
        case individualDefaultPrice
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    
    let plan: ChargingCostPlan?
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var cars: [Car]
    @Query(sort: \Charger.name) private var chargers: [Charger]
    @Query(sort: \Location.name) private var locations: [Location]
    @Query private var allPlans: [ChargingCostPlan]
    
    @State var car: Car?
    @State private var charger: Charger?
    @State private var planType: ChargingCostPlan.PlanType?
    
    @State private var selectedPlanType: String?
    private let planTypes = [
        ChargingCostPlan.PlanType.descriptionIndividual,
        ChargingCostPlan.PlanType.descriptionFlatrate,
        ChargingCostPlan.PlanType.descriptionHomeConsumption,
        ChargingCostPlan.PlanType.descriptionRefunded
    ]
    
    @State private var individualDefaultPrice: Cost = Cost(amount: 0.0)
    @State private var enterIndividualDefaultPrice: Bool = false
    @State private var flatratePrice: Cost = Cost(amount: 0.0)
    @State private var connectedLocation: Location?
    @State private var refundingPlan: ChargingCostPlan?
    @State private var isArchived: Bool = false
    
    @FocusState private var focusedField: Field?
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    private var editorTitle: String {
        plan == nil ? NSLocalizedString("New Plan", comment: "") : NSLocalizedString("Edit Plan", comment: "")
    }
    
    var body: some View {
        Form {
            // Car
            Picker("Car", selection: $car) {
                Text("- Select a car -").tag(nil as Car?)
                ForEach(cars) { car in
                    Text(car.description).tag(car)
                }
            }
            
            // Charger
            Picker("Charger", selection: $charger) {
                Text("- Select a charger -").tag(nil as Charger?)
                ForEach(chargers) { charger in
                    Text("\(charger.description)").tag(charger)
                }
            }
            .onChange(of: charger) {
                if let charger, let location = charger.location {
                    self.connectedLocation = location
                } else {
                    self.connectedLocation = nil
                }
            }
            
            // Charging Cost Plan
            Picker("Plan Type", selection: $selectedPlanType) {
                Text("- Select a plan type -").tag(nil as String?)
                ForEach(planTypes, id: \.self) { planType in
                    Text(planType).tag(planType)
                }
            }
            
            planDataView()
            
            Toggle("Archived", isOn: $isArchived)
                .padding(.top)
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
                // Edit the incoming plan.
                car = plan.car
                charger = plan.charger
                planType = plan.planType
                selectedPlanType = plan.planType.description
                isArchived = plan.isArchived
                
                switch plan.planType {
                case .individual(defaultKWhPrice: let price):
                    if price != nil {
                        individualDefaultPrice = price!
                    }
                    enterIndividualDefaultPrice = true
                case .flatrate(monthlyRate: let price):
                    flatratePrice = price
                case .homeConsumption(atLocationWithId: let locationId):
                    if let location = getLocationById(locationId) {
                        connectedLocation = location
                    } else {
                        activeAlert = .fatalError(message: "No location found.")
                    }
                case .refunded(atLocationWithId: let locationId, byFlatrateWithID: let flatrateId):
                    if let location = getLocationById(locationId) {
                        connectedLocation = location
                    } else {
                        activeAlert = .fatalError(message: "No location found.")
                    }
                    if let flatrate = allPlans.first(where: { $0.id == flatrateId }) {
                        refundingPlan = flatrate
                    } else {
                        activeAlert = .fatalError(message: "No refunding cost plan found.")
                    }
                }
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
    
    private func deleteIndividualDefaultPrice() {
        enterIndividualDefaultPrice = false
    }
    
    private func getLocationById(_ id: UUID) -> Location? {
        locations.first(where: { $0.id == id })
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
        if selectedPlanType == nil {
            activeAlert = .error(message: "Please select a plan type.")
            showingAlert = true
            return
        }
        
        // Update plan type
        switch selectedPlanType! {
        case ChargingCostPlan.PlanType.descriptionIndividual:
            planType = .individual(defaultKWhPrice: individualDefaultPrice)
        case ChargingCostPlan.PlanType.descriptionFlatrate:
            planType = .flatrate(monthlyRate: flatratePrice)
        case ChargingCostPlan.PlanType.descriptionHomeConsumption:
            if let connectedLocation {
                planType = .homeConsumption(atLocationWithId: connectedLocation.id)
            } else {
                activeAlert = .warning(message: "Please select a location.")
                showingAlert = true
            }
        case ChargingCostPlan.PlanType.descriptionRefunded:
            if connectedLocation == nil {
                activeAlert = .warning(message: "Please select a location.")
                showingAlert = true
                return
            }
            
            if refundingPlan == nil {
                activeAlert = .warning(message: "Please select a refunding plan.")
                showingAlert = true
                return
            }
            
            planType = .refunded(
                atLocationWithId: connectedLocation!.id,
                byFlatrateWithID: refundingPlan!.id
            )
        default:
            activeAlert = .fatalError(message: "Unsupported plan type: \(selectedPlanType!)")
            showingAlert = true
            return
        }
        
        if let plan {
            // Edit the car
            plan.car = car!
            plan.charger = charger!
            plan.planType = planType!
            plan.isArchived = isArchived
        } else {
            let newPlan = ChargingCostPlan(car: car!, charger: charger!, planType: planType!)
            newPlan.isArchived = isArchived
            modelContext.insert(newPlan)
        }
        
        // Save data and leave editor
        try? modelContext.save()
        navigationPath.removeLast()
    }
    
    @ViewBuilder
    private func planDataView() -> some View {
        switch selectedPlanType {
        case ChargingCostPlan.PlanType.descriptionIndividual:
            // Default cost
            if enterIndividualDefaultPrice {
                HStack {
                    Text("Default price")
                    Spacer()
                    TextField("", value: $individualDefaultPrice.amount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .individualDefaultPrice)
                    Text("\(individualDefaultPrice.currency)/kWh")
                    Button {
                        deleteIndividualDefaultPrice()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
            } else {
                // Offer to enter price
                HStack {
                    Text("Default price")
                    Spacer()
                    Button {
                        focusedField = .individualDefaultPrice
                        enterIndividualDefaultPrice = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
            }
        case ChargingCostPlan.PlanType.descriptionFlatrate:
            HStack {
                Text("Monthly price")
                Spacer()
                TextField("", value: $flatratePrice.amount, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text(individualDefaultPrice.currency)
            }
        case ChargingCostPlan.PlanType.descriptionHomeConsumption:
            Picker("Location", selection: $connectedLocation) {
                Text("- Select a location -").tag(nil as Location?)
                ForEach(locations, id: \.id) { location in
                    Text(location.name).tag(location)
                }
            }
        case ChargingCostPlan.PlanType.descriptionRefunded:
            Picker("Location", selection: $connectedLocation) {
                Text("- Select a location -").tag(nil as Location?)
                ForEach(locations, id: \.id) { location in
                    Text(location.name).tag(location)
                }
            }
            
            Picker("Refunding Plan", selection: $refundingPlan) {
                Text("- Select a plan -").tag(nil as ChargingCostPlan?)
                ForEach(allPlans, id: \.self) { plan in
                    Text(plan.descriptionShortNoCar).tag(plan)
                }
            }
        case .none:
            EmptyView()
        case .some(_):
            EmptyView()
        }
    }
}
