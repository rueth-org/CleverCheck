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
    @State var car: Car?
    
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var cars: [Car]
    @Query(sort: \Charger.name) private var chargers: [Charger]
    
    @State private var charger: Charger?
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
    
    @FocusState private var focusedField: Field?
    @State private var showingAlert = false
    @State private var activeAlert: SimpleAlertType?
    
    private var editorTitle: String {
        chargingSession == nil ? "New Session" : "Edit Session"
    }
    
    var body: some View {
        VStack {
            Form {
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
                        Text(UserSettings.settings.distanceUnit.symbol)
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
                self.charger = chargingSession.charger
                self.chargedEnergy = chargingSession.chargedEnergy
                self.car = chargingSession.car
                if let mileage = chargingSession.mileage {
                    self.mileage = mileage
                    self.enterMileage = true
                } else {
                    self.mileage = .init(value: 0, unit: UserSettings.settings.distanceUnit)
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
    
    private func deleteStartTime() {
        enterStartTime = false
    }
    
    private func deleteMileage() {
        enterMileage = false
        mileage = .init(value: 0, unit: UserSettings.settings.distanceUnit)
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
            chargingSession.charger = self.charger!
            chargingSession.chargedEnergy = self.chargedEnergy
            chargingSession.car = self.car!
            chargingSession.mileage = enterMileage ? self.mileage : nil
            chargingSession.initialSOC = enterInitialSOC ? self.initialSOC : nil
            chargingSession.finalSOC = enterFinalSOC ? self.finalSOC : nil
        } else {
            // Create new charging session
            let newSession = ChargingSession(endTime: self.endTime, charger: self.charger!, chargedEnergy: self.chargedEnergy, car: self.car!)
            newSession.startTime = enterStartTime ? self.startTime : nil
            newSession.mileage = enterMileage ? self.mileage : nil
            newSession.initialSOC = enterInitialSOC ? self.initialSOC : nil
            newSession.finalSOC = enterFinalSOC ? self.finalSOC : nil
            modelContext.insert(newSession)
        }
        
        // Leave edit mode
        navigationPath.removeLast()
    }
    
    private func cancelAndExit() {
        // Leave edit mode
        navigationPath.removeLast()
    }
}
