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
    @Bindable var chargingSession: ChargingSession
    @Binding var navigationPath: NavigationPath
    
    @Query private var cars: [Car]
    @Query private var chargingLocations: [ChargingLocation]
    
    @State private var enterStartTime: Bool = false
    @State private var startTime: Date
    @State private var enterMileage: Bool = false
    @State private var mileage: Int = 0
    @State private var enterInitialSOC: Bool = false
    @State private var initialSOC: Double = 0.1
    @State private var enterFinalSOC: Bool = false
    @State private var finalSOC: Double = 0.8
    
    @FocusState private var focusedField: Field?
    @State private var showingAlert = false
    @State private var activeAlert: SimpleAlertType?
    
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
                    if chargingSession.startTime != nil {
                        // Start has been entered
                        HStack {
                            Text("Start")
                            Spacer()
                            Text(ChargingSessionView.dateFormatter.string(from: chargingSession.startTime!))
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
                DatePicker("End", selection: $chargingSession.endTime)
                
                // Car
                Picker("Car", selection: $chargingSession.car) {
                    ForEach(cars) { car in
                        Text("\(car.make) \(car.model)").tag(car)
                    }
                }
                
                // Location
                Picker("Location", selection: $chargingSession.chargingLocation) {
                    Text("- none -").tag(nil as ChargingLocation?)
                    ForEach(chargingLocations) { location in
                        Text("\(location.name)").tag(location)
                    }
                }
                
                // Amount
                HStack {
                    Text("Amount")
                    TextField("Amount", value: $chargingSession.amount, format: .number)
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
                    if chargingSession.mileage != nil {
                        // Mileage has been entered
                        HStack {
                            Text("Mileage")
                            Spacer()
                            Text("\(chargingSession.mileage ?? 0) \(UserSettings.userSettings.unitDistance.rawValue)")
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
                    if chargingSession.initialSOC != nil {
                        // Initial SOC has been entered
                        HStack {
                            Text("Initial SOC")
                            Spacer()
                            Text(chargingSession.initialSOC!.formatted(.percent))
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
                    if chargingSession.finalSOC != nil {
                        // Final SOC has been entered
                        HStack {
                            Text("Final SOC")
                            Spacer()
                            Text(chargingSession.finalSOC!.formatted(.percent))
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
                Text("Charging Session") // TODO replace with editorTitle
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
    
    init(chargingSession: ChargingSession, navigationPath: Binding<NavigationPath>) {
        self.chargingSession = chargingSession
        self._navigationPath = navigationPath
        self.startTime = chargingSession.startTime ?? chargingSession.endTime.addingTimeInterval(-10800)
        
        // TODO: Filter charging locations
        /*
        _chargingLocations = Query(filter: #Predicate {
            $0.car == chargingSession.car
        }, sort: [SortDescriptor(\ChargingLocation.name)])*/
    }
    
    private func addStartTime() {
        if startTime >= chargingSession.endTime {
            activeAlert = .error(message: "Start time must be before end time.")
        } else {
            chargingSession.startTime = startTime
            enterStartTime = false
        }
    }
    
    private func deleteStartTime() {
        chargingSession.startTime = nil
    }
    
    private func addMileage() {
        // TODO check if mileage less than max
        
        chargingSession.mileage = mileage
        focusedField = nil
        enterMileage = false
    }
    
    private func deleteMileage() {
        chargingSession.mileage = nil
        mileage = 0
    }
    
    private func addInitialSOC() {
        // TODO data checks
        
        chargingSession.initialSOC = initialSOC
        focusedField = nil
        enterInitialSOC = false
    }
    
    private func deleteInitialSOC() {
        chargingSession.initialSOC = nil
        initialSOC = 0.2
    }
    
    private func addFinalSOC() {
        // TODO data checks
        
        chargingSession.finalSOC = finalSOC
        focusedField = nil
        enterFinalSOC = false
    }
    
    private func deleteFinalSOC() {
        chargingSession.finalSOC = nil
        finalSOC = 0.8
    }
    
    private func saveAndExit() {
        modelContext.insert(chargingSession)
        
        // Leave edit mode
        navigationPath.removeLast()
    }
    
    private func cancelAndExit() {
        // Leave edit mode
        navigationPath.removeLast()
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()
    let car = Car(make: "Toyota", model: "Rav4")
    let chargingSession = ChargingSession(
        endTime: Date.now,
        amount: 0.0,
        car: car
    )
    ChargingSessionView(
        chargingSession: chargingSession,
        navigationPath: $navigationPath
    )
}
