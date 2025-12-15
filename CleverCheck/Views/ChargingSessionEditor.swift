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
        chargingCostPlans.filter({
            if $0.car == nil || selectedCar == nil  {
                return true // Show all
            } else {
                return $0.car!.id == selectedCar!.id
            }
        })
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
                        .onChange(of: chargingCostPlan) { oldValue, newValue in
                            if newValue != nil {
                                self.selectedCar = newValue!.car
                            } else {
                                self.selectedCar = nil
                            }
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
                if let startTime = chargingSession.startTime {
                    self.startTime = startTime
                    self.enterStartTime = true
                } else {
                    self.startTime = chargingSession.endTime.addingTimeInterval(-10800) // 3h
                    self.enterStartTime = false
                }
                self.endTime = chargingSession.endTime
                self.chargedEnergy = chargingSession.chargedEnergy
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
        // Data check: No plan selected
        if chargingCostPlan == nil {
            activeAlert = .error(message: "Please select a plan.")
            showingAlert = true
            return
        }
        
        // Data check: start time before end time
        if startTime >= endTime {
            activeAlert = .error(message: "Start time must be before end time.")
            showingAlert = true
            return
        }
        
        // TODO check if mileage less than max
        
        // Save data
        if let chargingSession {
            // Updating an existing charging session
            chargingSession.startTime = enterStartTime ? self.startTime : nil
            chargingSession.endTime = self.endTime
            chargingSession.chargingCostPlan = self.chargingCostPlan!
            chargingSession.chargedEnergy = self.chargedEnergy
            chargingSession.mileage = enterMileage ? self.mileage : nil
            chargingSession.initialSOC = enterInitialSOC ? self.initialSOC : nil
            chargingSession.finalSOC = enterFinalSOC ? self.finalSOC : nil
            chargingSession.comment = self.comment
        } else {
            // Create new charging session
            let newSession = ChargingSession(endTime: self.endTime, chargedEnergy: self.chargedEnergy, chargingCostPlan: self.chargingCostPlan!)
            newSession.startTime = enterStartTime ? self.startTime : nil
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
