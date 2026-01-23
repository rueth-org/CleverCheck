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
    
    @Query private var cars: [Car]
    
    @Query(filter: #Predicate<Charger> { charger in
        charger.isArchived == false
    }, sort: \Charger.name) private var chargers: [Charger]
    
    @Query(filter: #Predicate<ChargingCostPlan> { plan in
        plan.isArchived == false
    }) private var allPlans: [ChargingCostPlan]
    
    @State var car: Car?
    @State private var charger: Charger?
    
    @State private var selectedPlanType: String?
    private let planTypes = [
        ChargingCostPlan.PlanType.individual.description,
        ChargingCostPlan.PlanType.flatrate.description,
        ChargingCostPlan.PlanType.homeConsumption.description,
        ChargingCostPlan.PlanType.refunded.description
    ]
    
    @State private var individualDefaultPrice: Cost = Cost(amount: 0.0)
    @State private var energyUnitSymbol: String = "kWh"
    @State private var enterIndividualDefaultPrice: Bool = false
    @State private var flatratePrice: Cost = Cost(amount: 0.0)
    @State private var refundingPlan: ChargingCostPlan?
    @State private var isArchived: Bool = false
    
    @FocusState private var focusedField: Field?
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?
    
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
                selectedPlanType = plan.planType.description
                energyUnitSymbol = plan.energyUnitSymbol
                isArchived = plan.isArchived
                
                switch plan.planType {
                case .individual:
                    if let originalPrice = plan.defaultEnergyPrice {
                        if let price = originalPrice.converted(to: UserSettings.shared.currencyIdentifier) {
                            convertEnergyUnit(plan, price)
                        } else {
                            // Conversion error, inform user and use original value
                            activeAlert = SimpleAlert(type: .fatalError(message: "Could not convert currency, showing original currency \(originalPrice.currency)."))
                            showingAlert = true
                            convertEnergyUnit(plan, originalPrice)
                        }
                    } else {
                        enterIndividualDefaultPrice = false
                    }
                case .flatrate:
                    if let originalRate = plan.monthlyRate {
                        if let rate = originalRate.converted(to: UserSettings.shared.currencyIdentifier) {
                            flatratePrice = rate
                        } else {
                            // Conversion error, inform user and use original value
                            activeAlert = SimpleAlert(type: .fatalError(message: "Could not convert currency, showing original currency \(originalRate.currency)."))
                            showingAlert = true
                            flatratePrice = originalRate
                        }
                    }
                case .homeConsumption:
                    guard (plan.charger?.location) != nil else {
                        activeAlert = SimpleAlert(type: .fatalError(message: "Related charger has no location."))
                        showingAlert = true
                        return
                    }
                case .refunded:
                    guard (plan.charger?.location) != nil else {
                        activeAlert = SimpleAlert(type: .fatalError(message: "Related charger has no location."))
                        showingAlert = true
                        return
                    }
                    if let includedInOtherPlan = plan.includedInOtherPlan {
                        refundingPlan = includedInOtherPlan
                    } else {
                        activeAlert = SimpleAlert(type: .fatalError(message: "No refunding cost plan found."))
                    }
                }
            }
        }
        .alert(
            activeAlert?.title() ?? "Notice",
            isPresented: $showingAlert,
            presenting: activeAlert
        ) { activeAlert in
            activeAlert.actionButtons()
        } message: { activeAlert in
            activeAlert.message()
        }
    }
    
    init(
        navigationPath: Binding<NavigationPath>,
        plan: ChargingCostPlan?,
        car: Car? = nil
    ) {
        self._navigationPath = navigationPath
        self.plan = plan
        self._car = State(initialValue: car)
        
        let predicate = #Predicate<Car> { car in
            car.isArchived == false
        }
        
        _cars = Query(
            filter: predicate,
            sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]
        )
    }
    
    private func deleteIndividualDefaultPrice() {
        enterIndividualDefaultPrice = false
    }
    
    private func cancelAndExit() {
        navigationPath.removeLast()
    }
    
    private func saveAndExit() {
        // Data check: No car selected
        if car == nil {
            activeAlert = SimpleAlert(type: .error(message: "Please select a car."))
            showingAlert = true
            return
        }
        
        // Data check: No charger selected
        if charger == nil {
            activeAlert = SimpleAlert(type: .error(message: "Please select a charger."))
            showingAlert = true
            return
        }
        
        // Data check: No plan selected
        if selectedPlanType == nil {
            activeAlert = SimpleAlert(type: .error(message: "Please select a plan type."))
            showingAlert = true
            return
        }
        
        var tempPlanType: ChargingCostPlan.PlanType? = nil
        var tempIndividualDefaultPrice: Cost? = nil
        var tempFlatratePrice: Cost? = nil
        var tempRefundingPlan: ChargingCostPlan? = nil
        
        // Update plan type
        switch selectedPlanType! {
        case ChargingCostPlan.PlanType.individual.description:
            tempPlanType = .individual
            tempIndividualDefaultPrice = enterIndividualDefaultPrice ? individualDefaultPrice : nil
        case ChargingCostPlan.PlanType.flatrate.description:
            tempPlanType = .flatrate
            tempFlatratePrice = flatratePrice
        case ChargingCostPlan.PlanType.homeConsumption.description:
            guard charger?.location != nil else {
                activeAlert = SimpleAlert(type: .error(message: "Please select a charger with a known location."))
                showingAlert = true
                return
            }
            tempPlanType = .homeConsumption
        case ChargingCostPlan.PlanType.refunded.description:
            tempPlanType = .refunded
            
            guard charger?.location != nil else {
                activeAlert = SimpleAlert(type: .error(message: "Please select a charger with a known location."))
                showingAlert = true
                return
            }
            
            if let refundingPlan {
                tempRefundingPlan = refundingPlan
            } else {
                activeAlert = SimpleAlert(type: .warning(message: "Please select a refunding plan."))
                showingAlert = true
                return
            }
        default:
            activeAlert = SimpleAlert(type: .fatalError(message: "Unsupported plan type: \(selectedPlanType!)"))
            showingAlert = true
            return
        }
        
        if let plan {
            // Edit the car
            plan.car = car!
            plan.charger = charger!
            plan.planType = tempPlanType!
            plan.energyUnitSymbol = energyUnitSymbol
            plan.defaultEnergyPrice = tempIndividualDefaultPrice
            plan.monthlyRate = tempFlatratePrice
            plan.includedInOtherPlan = tempRefundingPlan
            plan.isArchived = isArchived
        } else {
            let newPlan = ChargingCostPlan(
                car: car!,
                charger: charger!,
                planType: tempPlanType!,
                defaultEnergyPrice: tempIndividualDefaultPrice,
                monthlyRate: tempFlatratePrice,
                includedInOtherPlan: tempRefundingPlan
            )
            newPlan.energyUnitSymbol = energyUnitSymbol
            newPlan.isArchived = isArchived
            modelContext.insert(newPlan)
        }
        
        // Save data and leave editor
        try? modelContext.save()
        navigationPath.removeLast()
    }
    
    fileprivate func convertEnergyUnit(_ plan: ChargingCostPlan, _ price: Cost) {
        // Check if user has changed energy unit and convert if yes
        if plan.energyUnitSymbol == UserSettings.shared.energyUnitSymbol {
            // Use price without conversion
            individualDefaultPrice = price
        } else {
            // Convert to new unit
            if let defaultPrice = UserSettings.shared.convertEnergyPrice(amount: price.amount, from: plan.energyUnitSymbol, to: UserSettings.shared.energyUnitSymbol) {
                individualDefaultPrice = Cost(amount: defaultPrice, currency: price.currency)
                energyUnitSymbol = UserSettings.shared.energyUnitSymbol
            } else {
                // The energy unit symbol is unknown, assume default
                individualDefaultPrice = price
                energyUnitSymbol = UserSettings.shared.energyUnitSymbol
                
                // Inform the user
                activeAlert = SimpleAlert(type: .error(message: "Unknown energy unit: \(plan.energyUnitSymbol). Assuming default: \(UserSettings.shared.energyUnitSymbol). Please check your values."))
                showingAlert = true
            }
        }
        enterIndividualDefaultPrice = true
    }
    
    @ViewBuilder
    private func planDataView() -> some View {
        switch selectedPlanType {
        case ChargingCostPlan.PlanType.individual.description:
            // Default cost
            if enterIndividualDefaultPrice {
                HStack {
                    Text("Default price per \(energyUnitSymbol)")
                    Spacer()
                    TextField("", value: $individualDefaultPrice.amount, format: .currency(code: individualDefaultPrice.currency))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .individualDefaultPrice)
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
        case ChargingCostPlan.PlanType.flatrate.description:
            HStack {
                Text("Monthly price")
                Spacer()
                TextField("", value: $flatratePrice.amount, format: .currency(code: flatratePrice.currency))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        case ChargingCostPlan.PlanType.homeConsumption.description:
            HStack {
                Text("Location:")
                Spacer()
                Text(charger?.location?.name ?? "-")
            }
        case ChargingCostPlan.PlanType.refunded.description:
            HStack {
                Text("Location:")
                Spacer()
                Text(charger?.location?.name ?? "-")
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
