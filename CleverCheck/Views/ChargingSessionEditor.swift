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
    
    private enum CostType {
        case cost
        case specificCost
    }
    @State private var costType: CostType = .cost
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @State private var chargingSession: ChargingSession?
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var cars: [Car]
    @Query private var chargingCostPlans: [ChargingCostPlan]
    
    var possibleHomeConsumptionsRefunded: [HomeConsumption]? {
        chargingSession?.possibleHomeConsumptionsRefunded(modelContext: modelContext, ignorePlan: ignorePlan, ignoreDate: ignoreDate)
    }
    var possibleHomeConsumptions: [HomeConsumption]? {
        chargingSession?.possibleHomeConsumptions(modelContext: modelContext, ignoreDate: ignoreDate)
    }
    
    @State private var selectedCar: Car?
    @State private var chargingCostPlan: ChargingCostPlan?
    @State private var enterStartTime: Bool = false
    @State private var startTime: Date = Date.now.addingTimeInterval(-10800) // -3h
    @State private var endTime: Date = Date.now
    @State private var chargedEnergy: Measurement<UnitEnergy> = .init(value: 0, unit: .kilowattHours)
    @State private var enterCost: ChargingSession.CostCalculationMethod = .none
    @State private var cost: Cost = .init(amount: 0, currency: UserSettings.shared.currencyIdentifier)
    @State private var specificCost: Cost = .init(amount: 0, currency: UserSettings.shared.currencyIdentifier)
    @State private var estimatedRealCost: Cost?
    @State private var enterMileage: Bool = false
    @State private var mileage: Measurement<UnitLength> = .init(value: 0, unit: .kilometers)
    @State private var enterInitialSOC: Bool = false
    @State private var initialSOC: Double = 0.2
    @State private var enterFinalSOC: Bool = false
    @State private var finalSOC: Double = 0.8
    @State private var relatedHomeConsumption: HomeConsumption?
    @State private var relatedRefundingHomeConsumption: HomeConsumption?
    @State private var comment: String = ""
    @State private var isArchived: Bool = false
    
    @State private var ignorePlan: Bool = false
    @State private var ignoreDate: Bool = false
    @State private var chooseHomeConsumptionLater: Bool = false
    @State private var chooseRefundingHomeConsumptionLater: Bool = false
    
    @State private var isShowingHomeConsumptionPickerSheet: Bool = false
    @State private var isShowingRefundingHomeConsumptionPickerSheet: Bool = false
    
    @State private var isShowingCurrencySelector: Bool = false
    @State private var selectedCurrency: String = UserSettings.shared.currencyIdentifier
    
    @State private var proposedData: TextRecognizer? = nil
    
    @FocusState private var focusedField: Field?
    @State private var showingAlert = false
    @State private var activeAlert: SimpleAlert?
    
    private var shownPlans: [ChargingCostPlan] {
        chargingCostPlans.filter { plan in
            // If either plan has no car or no selected car, show the plan
            guard let planCar = plan.car, let selCar = selectedCar else { return true }
            return planCar.persistentModelID == selCar.persistentModelID
        }
    }
    
    private var totalChargingCost: Cost? {
        switch enterCost {
        case .none: return .init(amount: 0.0)
        case .absolute:
            return cost.converted(to: UserSettings.shared.currencyIdentifier)
        case .specific:
            if let convertedCost = specificCost.converted(to: UserSettings.shared.currencyIdentifier) {
                return .init(amount: convertedCost.amount * chargedEnergy.value)
            } else {
                return nil
            }
        case .both:
            if let cost = cost.converted(to: UserSettings.shared.currencyIdentifier), let convertedCost = specificCost.converted(to: UserSettings.shared.currencyIdentifier) {
                return .init(amount: cost.amount + convertedCost.amount * chargedEnergy.value)
            } else {
                return nil
            }
        }
    }
    
    private var editorTitle: String {
        chargingSession == nil ? NSLocalizedString("New Session", comment: "") : NSLocalizedString("Edit Session", comment: "")
    }
    
    var body: some View {
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
            
            // When editing a session (if new, we present it later after saving) ...
            if chargingSession != nil, chargingCostPlan?.planType != .individual {
                // Ask for a home consumption
                HStack {
                    Text("Related home consumption: \(relatedHomeConsumption?.descriptionWithDate ?? "-")")
                    Spacer()
                    Button(action: {
                        isShowingHomeConsumptionPickerSheet = true
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .sheet(isPresented: $isShowingHomeConsumptionPickerSheet) {
                        HomeConsumptionPicker(
                            possibleHomeConsumptions: chargingCostPlan?.planType == .refunded ? possibleHomeConsumptionsRefunded : possibleHomeConsumptions,
                            selectedHomeConsumption: $relatedHomeConsumption,
                            chooseLater: $chooseHomeConsumptionLater,
                            ignorePlan: $ignorePlan,
                            ignoreDate: $ignoreDate
                        )
                        .presentationDetents([.medium, .large])
                    }
                }
            }
            
            // When editing a session (if new, we present it later after saving) ...
            if chargingSession != nil, chargingCostPlan?.planType == .refunded {
                // Ask for a refunding home consumption
                HStack {
                    Text("Home consumption for refunding: \(relatedRefundingHomeConsumption?.descriptionWithDate ?? "-")")
                    Spacer()
                    Button(action: {
                        isShowingRefundingHomeConsumptionPickerSheet = true
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .sheet(isPresented: $isShowingRefundingHomeConsumptionPickerSheet) {
                        HomeConsumptionPicker(
                            possibleHomeConsumptions: possibleHomeConsumptions,
                            selectedHomeConsumption: $relatedRefundingHomeConsumption,
                            chooseLater: $chooseRefundingHomeConsumptionLater,
                            ignorePlan: $ignorePlan,
                            ignoreDate: $ignoreDate
                        )
                        .presentationDetents([.medium, .large])
                    }
                }
            }
            
            HStack {
                Button {
                    if selectedCar == nil {
                        activeAlert = SimpleAlert(type: .notice(message: "Please select a charging cost plan first"))
                        showingAlert = true
                    } else {
                        Task { await getDataFromImage(.camera) }
                    }
                } label: {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                        Text("Take picture")
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    if selectedCar == nil {
                        activeAlert = SimpleAlert(type: .notice(message: "Please select a charging cost plan first"))
                        showingAlert = true
                    } else {
                        Task { await getDataFromImage(.photoLibrary) }
                    }
                } label: {
                    HStack {
                        Image(systemName: "photo")
                        Text("Select picture")
                    }
                }
                .buttonStyle(.plain)
                .sheet(item: $proposedData) { data in
                    TextConfirmationView(
                        proposedData: data,
                        enterStart: $enterStartTime,
                        start: $startTime,
                        end: $endTime,
                        chargedEnergy: $chargedEnergy,
                        initialSOC: $initialSOC,
                        enterInitialSOC: $enterInitialSOC,
                        finalSOC: $finalSOC,
                        enterFinalSOC: $enterFinalSOC
                    )
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
                Button(action: {
                    if let estimate = calculateEnergy() {
                        self.chargedEnergy = estimate
                    }
                }) {
                    Image(systemName: "plusminus.circle.fill")
                }
                .disabled(!enterInitialSOC || !enterFinalSOC || finalSOC < initialSOC)
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
                    Button(action: {
                        costType = .cost
                        isShowingCurrencySelector = true
                    }) {
                        Image(systemName: "arrow.2.circlepath.circle")
                    }
                }
            }
            
            // Specific Cost (optional)
            if enterCost == .specific || enterCost == .both {
                HStack {
                    Text("Specific cost")
                    Spacer()
                    TextField("", value: $specificCost.amount, format: .currency(code: specificCost.currency))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Button(action: {
                        costType = .specificCost
                        isShowingCurrencySelector = true
                    }) {
                        Image(systemName: "arrow.2.circlepath.circle")
                    }
                }
            }
            
            if enterCost != .none {
                HStack {
                    Text("Total cost")
                    Spacer()
                    Text("\(totalChargingCost?.formatted() ?? "-")")
                }
                .foregroundStyle(.secondary)
            }
            
            // Estimated real cost
            HStack {
                Text("Estimated real cost")
                Spacer()
                Text("\(estimatedRealCost?.formatted() ?? "-")")
                Button {
                    Task {
                        do {
                            try await estimateRealCost()
                        } catch let error as EnergyDataService.EnergyDataError {
                            activeAlert = SimpleAlert(type: .error(message: "Failed to estimate real cost: \(error.errorDescription)"))
                            showingAlert = true
                        } catch {
                            activeAlert = SimpleAlert(type: .error(message: "Failed to estimate real cost: \(error.localizedDescription)"))
                            showingAlert = true
                        }
                    }
                } label: {
                    Image(systemName: "plusminus.circle.fill")
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
                    }
                }
            }
            
            TextField("Comments", text: $comment, axis: .vertical)
                .lineLimit(3)
            
            Toggle("Archived", isOn: $isArchived)
                .padding(.top)
            
            if let chargingSession {
                Button("Delete charging session", systemImage: "trash", role: .destructive) {
                    activeAlert = SimpleAlert(
                        type: .warning(message: "This will delete the charging session. Are you sure?"),
                        customButtons: [
                            SimpleAlertButton(title: NSLocalizedString("Cancel", comment: ""), role: .cancel) { },
                            SimpleAlertButton(title: NSLocalizedString("Delete", comment: ""), role: .destructive) {
                                delete(chargingSession)
                            }
                        ]
                    )
                    showingAlert = true
                }
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
                        save()
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
                if let estimatedRealCost = chargingSession.estimatedRealCost {
                    self.estimatedRealCost = estimatedRealCost
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
                if let relatedHomeConsumption = chargingSession.relatedHomeConsumption {
                    self.relatedHomeConsumption = relatedHomeConsumption
                }
                if let relatedRefundingHomeConsumption = chargingSession.relatedRefundingHomeConsumption {
                    self.relatedRefundingHomeConsumption = relatedRefundingHomeConsumption
                }
                if let comment = chargingSession.comment {
                    self.comment = comment
                }
                if let planType = chargingSession.chargingCostPlan?.planType, planType != .individual && relatedHomeConsumption == nil {
                    let possibleConsumptions = (planType == .refunded ? self.possibleHomeConsumptionsRefunded : self.possibleHomeConsumptions)
                    if let relatedHomeConsumption = assignUniqueHomeConsumption(possibleConsumptions) {
                        self.relatedHomeConsumption = relatedHomeConsumption
                        activeAlert = SimpleAlert(type: .notice(message: "Automatically determined related home consumption \(relatedHomeConsumption.descriptionWithDate). Please save this session or correct."))
                        showingAlert = true
                    }
                }
                if let planType = chargingSession.chargingCostPlan?.planType, planType == .refunded && relatedRefundingHomeConsumption == nil {
                    let possibleConsumptions = self.possibleHomeConsumptions
                    if let relatedRefundingHomeConsumption = assignUniqueHomeConsumption(possibleConsumptions) {
                        self.relatedRefundingHomeConsumption = relatedRefundingHomeConsumption
                        activeAlert = SimpleAlert(type: .notice(message: "Automatically determined related refunding home consumption \(relatedRefundingHomeConsumption.descriptionWithDate). Please save this session or correct."))
                        showingAlert = true
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCurrencySelector) {
            currencyPicker()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
        chargingSession: ChargingSession? = nil,
        selectedCar: Car? = nil
    ) {
        self._navigationPath = navigationPath
        self._chargingSession = State(initialValue: chargingSession)
        self._selectedCar = State(initialValue: selectedCar)
        
        var predicate: Predicate<ChargingCostPlan>
        if let selectedCar {
            // Filter charging cost plan query by car
            let id = selectedCar.persistentModelID
            predicate = #Predicate<ChargingCostPlan> { chargingCostPlan in
                if let car = chargingCostPlan.car {
                    return chargingCostPlan.isArchived == false && car.persistentModelID == id
                } else {
                    return chargingCostPlan.isArchived == false // Display all non-archived plans
                }
            }
        } else {
            predicate = #Predicate<ChargingCostPlan> { plan in
                plan.isArchived == false
            }
        }
        
        _chargingCostPlans = Query(filter: predicate)
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
    
    private func save() {
        // Ensure a plan is selected and bind it safely
        guard let selectedPlan = chargingCostPlan else {
            activeAlert = SimpleAlert(type: .error(message: "Please select a plan."))
            showingAlert = true
            return
        }

        // Data check: start time before end time
        if enterStartTime && startTime >= endTime {
            activeAlert = SimpleAlert(type: .error(message: "Start time must be before end time."))
            showingAlert = true
            return
        }

        // Data check: mileage
        if enterMileage {
            let mileageKilometer = mileage.converted(to: .kilometers)
            if let car = chargingCostPlan?.car {
                // Collect only sessions that have a mileage using compactMap, sorted by endTime
                let sessionsWithMileage = car.chargingSessions(in: nil).filter { $0.mileage != nil }
                
                if !sessionsWithMileage.isEmpty {
                    // Nearest previous (<= endTime) and nearest next (> endTime)
                    let prevSession = sessionsWithMileage.last(where: { $0.endTime <= endTime })
                    let nextSession = sessionsWithMileage.first(where: { $0.endTime > endTime })

                    // If there's no previous session, we're earlier than the earliest; compare to nextSession
                    if prevSession == nil, let next = nextSession, let nextMileage = next.mileage {
                        if mileageKilometer > nextMileage.converted(to: .kilometers) {
                            activeAlert = SimpleAlert(type: .error(message: "Mileage must be less or equal than \(UserSettings.shared.format(nextMileage.value, withSignificantDigits: 4)) \(nextMileage.unit.symbol)."))
                            showingAlert = true
                            return
                        }
                    }

                    // If there's no next session, we're later than the latest; compare to prevSession
                    if nextSession == nil, let prev = prevSession, let prevMileage = prev.mileage {
                        if mileageKilometer < prevMileage.converted(to: .kilometers) {
                            activeAlert = SimpleAlert(type: .error(message: "Mileage must be greater or equal than \(UserSettings.shared.format(prevMileage.value, withSignificantDigits: 4)) \(prevMileage.unit.symbol)."))
                            showingAlert = true
                            return
                        }
                    }

                    // If both exist, ensure the new mileage lies between them
                    if let prev = prevSession, let prevMileage = prev.mileage, let next = nextSession, let nextMileage = next.mileage {
                        if mileageKilometer < prevMileage.converted(to: .kilometers) || mileageKilometer > nextMileage.converted(to: .kilometers) {
                            activeAlert = SimpleAlert(type: .error(message: "Mileage must be between \(UserSettings.shared.format(prevMileage.value, withSignificantDigits: 4)) \(prevMileage.unit.symbol) and \(UserSettings.shared.format(nextMileage.value, withSignificantDigits: 4)) \(nextMileage.unit.symbol)."))
                            showingAlert = true
                            return
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
            chargingSession.estimatedRealCost = estimatedRealCost
            chargingSession.mileage = enterMileage ? self.mileage : nil
            chargingSession.initialSOC = enterInitialSOC ? self.initialSOC : nil
            chargingSession.finalSOC = enterFinalSOC ? self.finalSOC : nil
            chargingSession.relatedHomeConsumption = relatedHomeConsumption
            chargingSession.relatedRefundingHomeConsumption = relatedRefundingHomeConsumption
            chargingSession.comment = self.comment
        } else {
            // Create new charging session
            let newSession = ChargingSession(endTime: self.endTime, chargedEnergy: self.chargedEnergy, chargingCostPlan: selectedPlan)
            newSession.startTime = enterStartTime ? self.startTime : nil
            newSession.costCalculationMethod = self.enterCost
            newSession.chargingCost = enterCost == .absolute || enterCost == .both ? self.cost : nil
            newSession.specificChargingCost = enterCost == .specific || enterCost == .both ? self.specificCost : nil
            newSession.estimatedRealCost = estimatedRealCost
            newSession.mileage = enterMileage ? self.mileage : nil
            newSession.initialSOC = enterInitialSOC ? self.initialSOC : nil
            newSession.finalSOC = enterFinalSOC ? self.finalSOC : nil
            newSession.relatedHomeConsumption = relatedHomeConsumption
            newSession.relatedRefundingHomeConsumption = relatedRefundingHomeConsumption
            newSession.comment = self.comment
            modelContext.insert(newSession)
            self.chargingSession = newSession
        }
        
        // Save data
        try? modelContext.save()
        
        // Try to calculate the estimated real cost
        if estimatedRealCost == nil {
            Task {
                do {
                    try await estimateRealCost()
                    chargingSession?.estimatedRealCost = estimatedRealCost
                    try? modelContext.save() // Save the estimated real cost
                } catch {
                    // Ignore estimation errors at this stage, as the session is already saved. The user can trigger estimation again manually.
                }
            }
        }
        
        if (
            chooseHomeConsumptionLater ||
            selectedPlan.planType == .individual ||
            (selectedPlan.planType != .individual && relatedHomeConsumption != nil)
        ) && (
            chooseRefundingHomeConsumptionLater ||
            (selectedPlan.planType == .refunded && relatedRefundingHomeConsumption != nil)
        ) {
            andExit()
        } else {
            activeAlert = SimpleAlert(
                type: .notice(message: "Please connect to a home consumption."),
                customButtons: [
                    SimpleAlertButton(title: NSLocalizedString("Connect now", comment: ""), role: nil) {
                        // Open the home consumption picker
                        if selectedPlan.planType == .refunded {
                            isShowingRefundingHomeConsumptionPickerSheet = true
                        } else if selectedPlan.planType == .refunded && relatedRefundingHomeConsumption != nil {
                            isShowingHomeConsumptionPickerSheet = true
                        } else {
                            isShowingHomeConsumptionPickerSheet = true
                        }
                    },
                    SimpleAlertButton(title: NSLocalizedString("Connect later", comment: ""), role: nil) {
                        andExit()
                    }
                ]
            )
                
            showingAlert = true
        }
    }
    
    private func andExit() {
        navigationPath.removeLast()
    }
    
    private func cancelAndExit() {
        modelContext.rollback()
        
        // Leave edit mode
        navigationPath.removeLast()
    }
    
    private func addPlan() {
        navigationPath.append(ChargingCostPlansView.NavigationDestination.NewPlan(car: selectedCar))
    }
    
    private func delete(_ chargingSession: ChargingSession) {
        navigationPath.removeLast()
        modelContext.delete(chargingSession)
        try? modelContext.save()
    }
    
    private func calculateEnergy() -> Measurement<UnitEnergy>? {
        if let avgPerPP = selectedCar?.averageEnergyPerPercentPoint() {
            return .init(
                value: (finalSOC - initialSOC) * avgPerPP.converted(to: UserSettings.shared.energyUnit).value,
                unit: UserSettings.shared.energyUnit
            )
        } else {
            activeAlert = SimpleAlert(type: .warning(message: "An estimation of the charged energy requires initial SOC less than final SOC."))
            showingAlert = true
            return nil
        }
    }
    
    private func changeCurrency(to currencyIdentifier: String) {
        switch costType {
        case .cost:
            if self.cost.amount == 0 {
                self.cost = .init(amount: 0, currency: currencyIdentifier)
            } else {
                self.cost = self.cost.converted(to: currencyIdentifier) ?? self.cost
            }
        case .specificCost:
            if self.specificCost.amount == 0 {
                self.specificCost = .init(amount: 0, currency: currencyIdentifier)
            } else {
                self.specificCost = self.specificCost.converted(to: currencyIdentifier) ?? self.specificCost
            }
        }
    }
    
    private func assignUniqueHomeConsumption(_ possibleHomeConsumptions: [HomeConsumption]?) -> HomeConsumption? {
        if let possibleHomeConsumptions, possibleHomeConsumptions.count == 1 {
            if let relatedHomeConsumption = possibleHomeConsumptions.first {
                return relatedHomeConsumption
            }
        }
        return nil
    }
    
    private func estimateRealCost() async throws {
        if let chargingSession = chargingSession {
            let estimation = try await chargingSession.estimateRealCost(modelContext: modelContext)
            self.estimatedRealCost = estimation
        } else {
            activeAlert = SimpleAlert(type: .error(message: "Please save the charging session before estimating the real cost."))
            showingAlert = true
        }
    }
    
    @MainActor private func getDataFromImage(_ sourceType: UIImagePickerController.SourceType) async {
        if let car = selectedCar {
            do {
                let imageWithMetadata = try await ImageHandler.getImageWithMetadataFromCameraOrLibrary(sourceType)
                if let cgImage = imageWithMetadata.image.cgImage {
                    let recognizedText = try TextRecognizer.recognizeText(from: cgImage)
                    let proposedData = TextRecognizer(image: imageWithMetadata, recognizedText: recognizedText)
                    proposedData.analyse(for: car)
                    self.proposedData = proposedData
                } else {
                    activeAlert = SimpleAlert(type: .error(message: "Failed to get image"))
                    showingAlert = true
                }
            } catch {
                let errorDescription = String(describing: error)
                activeAlert = SimpleAlert(type: .error(message: "Image capture failed: \(errorDescription)"))
                showingAlert = true
            }
        }
    }
    
    @ViewBuilder
    private func currencyPicker() -> some View {
        VStack {
            Picker("Currency", selection: $selectedCurrency) {
                ForEach(UserSettings.shared.preferredCurrencies.sorted(), id: \.self) { code in
                    Text(verbatim: code).tag(code)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: selectedCurrency) {
                changeCurrency(to: selectedCurrency)
            }
            
            Text("Miss a currency? Add it in settings!")
                .font(.caption)
        }
    }
}

