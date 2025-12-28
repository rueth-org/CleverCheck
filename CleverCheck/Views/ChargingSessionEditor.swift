//
//  ChargingSessionView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

struct ChargingSessionEditor: View {
    private enum Field: Int, Hashable {
        case mileage, initialSOC, finalSOC
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    var chargingSession: ChargingSession?
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var cars: [Car]
    @Query private var chargingCostPlans: [ChargingCostPlan]
    
    @State private var selectedCar: Car?
    @State private var chargingCostPlan: ChargingCostPlan?
    @State private var enterStartTime: Bool = false
    @State private var startTime: Date = Date.now.addingTimeInterval(-10800) // -3h
    @State private var endTime: Date = Date.now
    @State private var chargedEnergy: Measurement<UnitEnergy> = .init(value: 0, unit: .kilowattHours)
    @State private var enterCost: ChargingSession.CostCalculationMethod = .none
    @State private var cost: Cost = .init(amount: 0, currency: UserSettings.shared.currencyIdentifier)
    @State private var specificCost: Cost = .init(amount: 0, currency: UserSettings.shared.currencyIdentifier)
    @State private var enterMileage: Bool = false
    @State private var mileage: Measurement<UnitLength> = .init(value: 0, unit: .kilometers)
    @State private var enterInitialSOC: Bool = false
    @State private var initialSOC: Double = 0.2
    @State private var enterFinalSOC: Bool = false
    @State private var finalSOC: Double = 0.8
    @State private var comment: String = ""
    @State private var isArchived: Bool = false
    
    @FocusState private var focusedField: Field?
    @State private var showingAlert = false
    @State private var activeAlert: SimpleAlertType?
    
    private var shownPlans: [ChargingCostPlan] {
        chargingCostPlans.filter { plan in
            // If either plan has no car or no selected car, show the plan
            guard let planCar = plan.car, let selCar = selectedCar else { return true }
            return planCar.persistentModelID == selCar.persistentModelID
        }
    }
    
    private var editorTitle: String {
        chargingSession == nil ? NSLocalizedString("New Session", comment: "") : NSLocalizedString("Edit Session", comment: "")
    }
    
    var body: some View {
        VStack {
            Form {
                // Display selected vehicle
                HStack {
                    Text("Vehicle")
                    Spacer()
                    if let selectedCar = selectedCar {
                        Text("\(selectedCar.make) \(selectedCar.model)")
                            .font(.headline)
                    } else {
                        Text("Please select a plan")
                            .italic()
                    }
                }
                
                // Charging Cost Plan
                if shownPlans.isEmpty {
                    HStack {
                        Button {
                            addPlan()
                        } label: {
                            HStack {
                                Text("Add Charging Cost Plan")
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                } else {
                    Picker("Charging Cost Plan", selection: $chargingCostPlan) {
                        Text("- Select a plan -").tag(nil as ChargingCostPlan?)
                        ForEach(shownPlans) { chargingCostPlan in
                            Text("\(selectedCar == nil ? chargingCostPlan.descriptionShort : chargingCostPlan.descriptionShortNoCar)").tag(chargingCostPlan)
                        }
                        .onChange(of: chargingCostPlan) { _oldValue, newValue in
                            // Update selectedCar to the plan's car (or nil) without force-unwrapping
                            self.selectedCar = newValue?.car
                        }
                    }
                }
                
                // Start time (optional)
                if enterStartTime {
                    HStack {
                        DatePicker("Start", selection: $startTime)
                        Button {
                            deleteStartTime()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                } else {
                    // Offer to enter start
                    HStack {
                        Text("Start")
                        Spacer()
                        Button {
                            enterStartTime = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                
                // End time
                DatePicker("End", selection: $endTime)
                
                // Amount
                HStack {
                    Text("Amount")
                    TextField("Amount", value: $chargedEnergy.value, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(chargedEnergy.unit.symbol)
                }
                
                // Cost
                Picker("Cost entry", selection: $enterCost) {
                    Text(ChargingSession.CostCalculationMethod.none.description()).tag(ChargingSession.CostCalculationMethod.none)
                    Text(ChargingSession.CostCalculationMethod.absolute.description()).tag(ChargingSession.CostCalculationMethod.absolute)
                    Text(ChargingSession.CostCalculationMethod.specific.description()).tag(ChargingSession.CostCalculationMethod.specific)
                    Text(ChargingSession.CostCalculationMethod.both.description()).tag(ChargingSession.CostCalculationMethod.both)
                }
                
                if enterCost == .absolute || enterCost == .both {
                    HStack {
                        Text("Cost")
                        Spacer()
                        TextField("", value: $cost.amount, format: .currency(code: cost.currency))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Specific Cost (optional)
                if enterCost == .specific || enterCost == .both {
                    HStack {
                        Text("Specific cost")
                        Spacer()
                        TextField("", value: $specificCost.amount, format: .currency(code: cost.currency))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Mileage (optional)
                if enterMileage {
                    HStack {
                        Text("Mileage")
                        Spacer()
                        TextField("", value: $mileage.value, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .mileage)
                        Text(UserSettings.shared.distanceUnit.symbol)
                        Button {
                            deleteMileage()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                } else {
                    // Offer to enter mileage
                    HStack {
                        Text("Mileage")
                        Spacer()
                        Button {
                            focusedField = .mileage
                            enterMileage = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                
                // Initial SOC (optional)
                if enterInitialSOC {
                    HStack {
                        Text("Initial SOC")
                        Spacer()
                        TextField("", value: $initialSOC, format: .percent)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .initialSOC)
                        Button {
                            deleteInitialSOC()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                } else {
                    // Offer to enter initial SOC
                    HStack {
                        Text("Initial SOC")
                        Spacer()
                        Button {
                            focusedField = .initialSOC
                            enterInitialSOC = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                
                // Final SOC (optional)
                if enterFinalSOC {
                    HStack {
                        Text("Final SOC")
                        Spacer()
                        TextField("", value: $finalSOC, format: .percent)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .finalSOC)
                        Button {
                            deleteFinalSOC()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                } else {
                    // Offer to enter final SOC
                    HStack {
                        Text("Final SOC")
                        Spacer()
                        Button {
                            focusedField = .finalSOC
                            enterFinalSOC = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                
                TextField("Comments", text: $comment, axis: .vertical)
                    .lineLimit(3)
                
                Toggle("Archived", isOn: $isArchived)
                    .padding(.top)
            }
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
            if let chargingSession {
                // Edit the incoming charging session
                self.chargingCostPlan = chargingSession.chargingCostPlan
                self.selectedCar = chargingSession.chargingCostPlan?.car
                if let startTime = chargingSession.startTime {
                    self.startTime = startTime
                    self.enterStartTime = true
                } else {
                    self.startTime = chargingSession.endTime.addingTimeInterval(-10800) // 3h
                    self.enterStartTime = false
                }
                self.endTime = chargingSession.endTime
                self.chargedEnergy = chargingSession.chargedEnergy
                if let cost = chargingSession.chargingCost {
                    self.cost = cost
                }
                if let specificChargingCost = chargingSession.specificChargingCost {
                    self.specificCost = specificChargingCost
                }
                self.enterCost = chargingSession.costCalculationMethod
                if let mileage = chargingSession.mileage {
                    self.mileage = mileage
                    self.enterMileage = true
                } else {
                    self.mileage = .init(value: 0, unit: UserSettings.shared.distanceUnit)
                    self.enterMileage = false
                }
                if let initialSOC = chargingSession.initialSOC {
                    self.initialSOC = initialSOC
                    self.enterInitialSOC = true
                } else {
                    self.initialSOC = 0.2
                    self.enterInitialSOC = false
                }
                if let finalSOC = chargingSession.finalSOC {
                    self.finalSOC = finalSOC
                    self.enterFinalSOC = true
                } else {
                    self.finalSOC = 0.8
                    self.enterFinalSOC = false
                }
                if let comment = chargingSession.comment {
                    self.comment = comment
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
    
    init(
        navigationPath: Binding<NavigationPath>,
        chargingSession: ChargingSession? = nil,
        selectedCar: Car? = nil
    ) {
        self._navigationPath = navigationPath
        self.chargingSession = chargingSession
        self._selectedCar = State(initialValue: selectedCar)
        
        if let selectedCar {
            // Filter charging cost plan query by car
            let id = selectedCar.persistentModelID
            let predicate = #Predicate<ChargingCostPlan> { chargingCostPlan in
                if let car = chargingCostPlan.car {
                    return car.persistentModelID == id
                } else {
                    return true // Display all plans
                }
            }
            _chargingCostPlans = Query(filter: predicate)
        } else {
            _chargingCostPlans = Query()
        }
    }
    
    private func deleteStartTime() {
        enterStartTime = false
    }
    
    private func deleteMileage() {
        enterMileage = false
        mileage = .init(value: 0, unit: UserSettings.shared.distanceUnit)
    }
    
    private func deleteInitialSOC() {
        enterInitialSOC = false
        initialSOC = 0.2
    }
    
    private func deleteFinalSOC() {
        enterFinalSOC = false
        finalSOC = 0.8
    }
    
    private func saveAndExit() {
        // Ensure a plan is selected and bind it safely
        guard let selectedPlan = chargingCostPlan else {
            activeAlert = .error(message: "Please select a plan.")
            showingAlert = true
            return
        }

        // Data check: start time before end time
        if enterStartTime && startTime >= endTime {
            activeAlert = .error(message: "Start time must be before end time.")
            showingAlert = true
            return
        }

        // Data check: mileage
        if enterMileage {
            let mileageKilometer = mileage.converted(to: .kilometers)
            if let car = chargingCostPlan?.car {
                if let allPlans = car.chargingCostPlans {
                    // Collect only sessions that have a mileage using compactMap, sorted by endTime
                    let sessionsWithMileage = allPlans
                        .flatMap { $0.chargingSessions ?? [] }
                        .compactMap { $0.mileage != nil ? $0 : nil }
                        .sorted(by: { $0.endTime < $1.endTime })

                    if !sessionsWithMileage.isEmpty {
                        // Nearest previous (<= endTime) and nearest next (> endTime)
                        let prevSession = sessionsWithMileage.last(where: { $0.endTime <= endTime })
                        let nextSession = sessionsWithMileage.first(where: { $0.endTime > endTime })

                        // If there's no previous session, we're earlier than the earliest; compare to nextSession
                        if prevSession == nil, let next = nextSession, let nextMileage = next.mileage {
                            if mileageKilometer > nextMileage.converted(to: .kilometers) {
                                let m = nextMileage.value
                                let precision = UserSettings.shared.precision(for: m)
                                activeAlert = .error(message: "Mileage must be less or equal than \(m.formatted(.number.precision(.fractionLength(precision)))) \(nextMileage.unit.symbol).")
                                showingAlert = true
                                return
                            }
                        }

                        // If there's no next session, we're later than the latest; compare to prevSession
                        if nextSession == nil, let prev = prevSession, let prevMileage = prev.mileage {
                            if mileageKilometer < prevMileage.converted(to: .kilometers) {
                                let m = prevMileage.value
                                let precision = UserSettings.shared.precision(for: m)
                                activeAlert = .error(message: "Mileage must be greater or equal than \(m.formatted(.number.precision(.fractionLength(precision)))) \(prevMileage.unit.symbol).")
                                showingAlert = true
                                return
                            }
                        }

                        // If both exist, ensure the new mileage lies between them
                        if let prev = prevSession, let prevMileage = prev.mileage, let next = nextSession, let nextMileage = next.mileage {
                            if mileageKilometer < prevMileage.converted(to: .kilometers) || mileageKilometer > nextMileage.converted(to: .kilometers) {
                                let m = prevMileage.value
                                let n = nextMileage.value
                                let precision = UserSettings.shared.precision(for: m)
                                activeAlert = .error(message: "Mileage must be between \(m.formatted(.number.precision(.fractionLength(precision)))) \(prevMileage.unit.symbol) and \(n.formatted(.number.precision(.fractionLength(precision)))) \(nextMileage.unit.symbol).")
                                showingAlert = true
                                return
                            }
                        }
                    }
                }
            }
        }

        // Save data
        if let chargingSession {
            // Updating an existing charging session
            chargingSession.startTime = enterStartTime ? self.startTime : nil
            chargingSession.endTime = self.endTime
            chargingSession.chargingCostPlan = selectedPlan
            chargingSession.chargedEnergy = self.chargedEnergy
            chargingSession.costCalculationMethod = self.enterCost
            chargingSession.chargingCost = enterCost == .absolute || enterCost == .both ? self.cost : nil
            chargingSession.specificChargingCost = enterCost == .specific || enterCost == .both ? self.specificCost : nil
            chargingSession.mileage = enterMileage ? self.mileage : nil
            chargingSession.initialSOC = enterInitialSOC ? self.initialSOC : nil
            chargingSession.finalSOC = enterFinalSOC ? self.finalSOC : nil
            chargingSession.comment = self.comment
        } else {
            // Create new charging session
            let newSession = ChargingSession(endTime: self.endTime, chargedEnergy: self.chargedEnergy, chargingCostPlan: selectedPlan)
            newSession.startTime = enterStartTime ? self.startTime : nil
            newSession.costCalculationMethod = self.enterCost
            newSession.chargingCost = enterCost == .absolute || enterCost == .both ? self.cost : nil
            newSession.specificChargingCost = enterCost == .specific || enterCost == .both ? self.specificCost : nil
            newSession.mileage = enterMileage ? self.mileage : nil
            newSession.initialSOC = enterInitialSOC ? self.initialSOC : nil
            newSession.finalSOC = enterFinalSOC ? self.finalSOC : nil
            newSession.comment = self.comment
            modelContext.insert(newSession)
        }

        // Leave edit mode
        navigationPath.removeLast()
    }
    
    private func cancelAndExit() {
        // Leave edit mode
        navigationPath.removeLast()
    }
    
    private func addPlan() {
        navigationPath.append(ChargingCostPlansView.NavigationDestination.NewPlan(car: selectedCar))
    }
}

