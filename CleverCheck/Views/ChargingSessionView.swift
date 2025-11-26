//
//  ChargingSessionView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

struct ChargingSessionView: View {
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
    @Query(sort: \Charger.name) private var chargers: [Charger]
    
    @State private var enterStartTime: Bool = false
    @State private var startTimeEntered: Bool = false
    @State private var startTime: Date = Date.now.addingTimeInterval(-10800) // -3h
    @State private var endTime: Date = Date.now
    @State private var charger: Charger? = nil
    @State private var amount: Double = 0.0
    @State private var car: Car = Car.new()
    @State private var enterMileage: Bool = false
    @State private var mileageEntered: Bool = false
    @State private var mileage: Int = 0
    @State private var enterInitialSOC: Bool = false
    @State private var initialSOCEntered: Bool = false
    @State private var initialSOC: Double = 0.2
    @State private var enterFinalSOC: Bool = false
    @State private var finalSOCEntered: Bool = false
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
                // Start time
                if enterStartTime {
                    HStack {
                        DatePicker("Start", selection: $startTime)
                        Button {
                            addStartTime()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    if startTimeEntered {
                        // Start has been entered
                        HStack {
                            Text("Start")
                            Spacer()
                            Text(ChargingSessionView.dateFormatter.string(from: startTime))
                                .multilineTextAlignment(.trailing)
                            Button {
                                deleteStartTime()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .imageScale(.large)
                                    .foregroundStyle(.red)
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
                                    .imageScale(.large)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                
                // End time
                DatePicker("End", selection: $endTime)
                
                // Car
                Picker("Car", selection: $car) {
                    ForEach(cars) { car in
                        Text("\(car.make) \(car.model)").tag(car)
                    }
                }
                
                // Charger
                Picker("Charger", selection: $charger) {
                    Text("- none -").tag(nil as Charger?)
                    ForEach(chargers) { charger in
                        Text("\(charger.name)").tag(charger)
                    }
                }
                
                // Amount
                HStack {
                    Text("Amount")
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("kWh")
                }
                
                // Mileage (optional)
                if enterMileage {
                    HStack {
                        Text("Mileage")
                        Spacer()
                        TextField("", value: $mileage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .mileage)
                            .onSubmit {
                                addMileage()
                            }
                            .submitLabel(.done)
                        Text(UserSettings.userSettings.unitDistance.rawValue)
                        Button {
                            addMileage()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    if mileageEntered {
                        // Mileage has been entered
                        HStack {
                            Text("Mileage")
                            Spacer()
                            Text("\(mileage ?? 0) \(UserSettings.userSettings.unitDistance.rawValue)")
                                .multilineTextAlignment(.trailing)
                            Button {
                                deleteMileage()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .imageScale(.large)
                                    .foregroundStyle(.red)
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
                                    .imageScale(.large)
                                    .foregroundStyle(.green)
                            }
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
                            .onSubmit {
                                addInitialSOC()
                            }
                            .submitLabel(.done)
                        Button {
                            addInitialSOC()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    if initialSOCEntered {
                        // Initial SOC has been entered
                        HStack {
                            Text("Initial SOC")
                            Spacer()
                            Text(initialSOC.formatted(.percent))
                                .multilineTextAlignment(.trailing)
                            Button {
                                deleteInitialSOC()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .imageScale(.large)
                                    .foregroundStyle(.red)
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
                                    .imageScale(.large)
                                    .foregroundStyle(.green)
                            }
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
                            .onSubmit {
                                addFinalSOC()
                            }
                            .submitLabel(.done)
                        Button {
                            addFinalSOC()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    if finalSOCEntered {
                        // Final SOC has been entered
                        HStack {
                            Text("Final SOC")
                            Spacer()
                            Text(finalSOC.formatted(.percent))
                                .multilineTextAlignment(.trailing)
                            Button {
                                deleteFinalSOC()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .imageScale(.large)
                                    .foregroundStyle(.red)
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
                                    .imageScale(.large)
                                    .foregroundStyle(.green)
                            }
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
                    self.startTimeEntered = true
                } else {
                    self.startTime = chargingSession.endTime.addingTimeInterval(-10800) // 3h
                    self.startTimeEntered = false
                }
                self.endTime = chargingSession.endTime
                self.charger = chargingSession.charger
                self.amount = chargingSession.amount
                self.car = chargingSession.car
                if let mileage = chargingSession.mileage {
                    self.mileage = mileage
                    self.mileageEntered = true
                } else {
                    self.mileage = 0
                    self.mileageEntered = false
                }
                if let initialSOC = chargingSession.initialSOC {
                    self.initialSOC = initialSOC
                    self.initialSOCEntered = true
                } else {
                    self.initialSOC = 0.2
                    self.initialSOCEntered = false
                }
                if let finalSOC = chargingSession.finalSOC {
                    self.finalSOC = finalSOC
                    self.finalSOCEntered = true
                } else {
                    self.finalSOC = 0.8
                    self.finalSOCEntered = false
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
    
    private func addStartTime() {
        if startTime >= endTime {
            activeAlert = .error(message: "Start time must be before end time.")
        } else {
            startTimeEntered = true
            enterStartTime = false
        }
    }
    
    private func deleteStartTime() {
        startTimeEntered = false
    }
    
    private func addMileage() {
        // TODO check if mileage less than max
        
        focusedField = nil
        mileageEntered = true
        enterMileage = false
    }
    
    private func deleteMileage() {
        mileageEntered = false
        mileage = 0
    }
    
    private func addInitialSOC() {
        // TODO data checks
        
        focusedField = nil
        initialSOCEntered = true
        enterInitialSOC = false
    }
    
    private func deleteInitialSOC() {
        initialSOCEntered = false
        initialSOC = 0.2
    }
    
    private func addFinalSOC() {
        // TODO data checks
        
        focusedField = nil
        finalSOCEntered = true
        enterFinalSOC = false
    }
    
    private func deleteFinalSOC() {
        finalSOCEntered = false
        finalSOC = 0.8
    }
    
    private func saveAndExit() {
        if let chargingSession {
            // Updating an existing charging session
            chargingSession.startTime = startTimeEntered ? self.startTime : nil
            self.endTime = chargingSession.endTime
            self.charger = chargingSession.charger
            self.amount = chargingSession.amount
            self.car = chargingSession.car
            chargingSession.mileage = mileageEntered ? self.mileage : nil
            chargingSession.initialSOC = initialSOCEntered ? self.initialSOC : nil
            chargingSession.finalSOC = finalSOCEntered ? self.finalSOC : nil
        } else {
            // Create new charging session
            let newSession = ChargingSession(endTime: self.endTime, amount: self.amount, car: self.car)
            newSession.startTime = startTimeEntered ? self.startTime : nil
            newSession.charger = self.charger
            newSession.mileage = mileageEntered ? self.mileage : nil
            newSession.initialSOC = initialSOCEntered ? self.initialSOC : nil
            newSession.finalSOC = finalSOCEntered ? self.finalSOC : nil
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
