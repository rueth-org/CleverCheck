//
//  SettingsView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/12/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let completion: ((Bool, Error?) -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
            completion?(completed, activityError)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsView: View {
    enum NavigationDestination: Hashable {
        case Cars
        case Chargers
        case Locations
        case ChargingCostPlans
    }
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var cars: [Car]
    @Query private var chargingSessions: [ChargingSession]
    @State private var navigationPath = NavigationPath()
    
    // Observe UserSettings singleton so UI updates when preferredCurrencies change
    @ObservedObject private var userSettings = UserSettings.shared
    
    @State private var showingDeleteAllAlert = false
    @State private var confirmDeletion = ""
    
    @State private var showingUpdateChargingSessionsAlert: Bool = false
    @State private var updatedChargingSessions: [String] = []
    
    // Import states
    @State private var isImportingChargingSessionFile: Bool = false
    @State private var isImportingHomeConsumptionFile: Bool = false
    @State private var isImportingPriceElementFile: Bool = false
    @State private var importMessage: String = ""
    @State private var showImportResult: Bool = false
    @State private var showingCarPicker: Bool = false
    @State private var selectedImportCarIndex: Int? = nil
    @State private var selectedImportCar: Car? = nil
    
    // Export/share state
    @State private var isSharing: Bool = false
    @State private var exportFileURL: URL? = nil
    
    // Settings
    @AppStorage("measurementSystem") private var measurementSystemIdentifier: String = Locale.current.measurementSystem.identifier
    @AppStorage("currencyIdentifier") private var currencyIdentifier: String = Locale.current.currency?.identifier ?? "EUR"
    @AppStorage("energyUnitSymbol") private var energyUnitSymbol: String = "kWh"
    @AppStorage("powerUnitSymbol") private var powerUnitSymbol: String = "kW"
    @AppStorage("energyOverDistance") private var energyOverDistance: Bool = true
    @AppStorage("distanceMultiplier") private var distanceMultiplier: Int = 100
    @AppStorage("vatRate") private var vatRate: Double = 0.25
    @AppStorage("displayGrossPrices") private var displayGrossPrices: Bool = true
    @AppStorage("referenceSOC") private var referenceSOC: Double = 0.8
    
    @State private var isEditingSOC: Bool = false
    private let minSOC: Double = 0.5
    private let maxSOC: Double = 1.0
    
    @State private var isEditingVATRate: Bool = false
    @State private var showingCurrencySelector: Bool = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                Section(header: Text("Master Data")) {
                    Button("Cars") {
                        navigationPath.append(NavigationDestination.Cars)
                    }
                    Button("Locations") {
                        navigationPath.append(NavigationDestination.Locations)
                    }
                    Button("Chargers") {
                        navigationPath.append(NavigationDestination.Chargers)
                    }
                    Button("Charging Cost Plans") {
                        navigationPath.append(NavigationDestination.ChargingCostPlans)
                    }
                }
                
                Section(header: Text("Charging")) {
                    VStack {
                        HStack {
                            Text("Reference SOC")
                            Spacer()
                            Text(referenceSOC.formatted(.percent))
                                .foregroundColor(isEditingSOC ? .red : .primary)
                        }
                        Text("The reference SOC is used to calculate the average consumption of your vehicle. Consumption calculation will only be done, when you charge your vehicle to exactly this SOC and at the same time enter a mileage.")
                            .font(.footnote)
                            .padding(.vertical)
                        Slider(
                            value: $referenceSOC,
                            in: 0.5...1.0,
                            step: 0.05
                        ) {
                            Text("Reference SOC")
                        } minimumValueLabel: {
                            Text(minSOC.formatted(.percent))
                                .font(.caption)
                        } maximumValueLabel: {
                            Text(maxSOC.formatted(.percent))
                                .font(.caption)
                        } onEditingChanged: { editing in
                            isEditingSOC = editing
                        }
                    }
                    
                    VStack {
                        Toggle("Use related consumption", isOn: $userSettings.useRelatedConsumptions)
                        Text("When using related consumption, instead of using the consumption manually entered by the user, the app will use the consumption data from related charging sessions. This only applies for charging cost plans of type 'refunded' and only if the charging session has a related home consumption assigned. This can lead to more accurate cost calculations, but also to missing cost calculations if no related home consumption is assigned.")
                            .font(.footnote)
                            .padding(.vertical)
                    }
                }
                
                Section(header: Text("Units")) {
                    Picker("Measurement system", selection: $measurementSystemIdentifier) {
                        ForEach(Locale.MeasurementSystem.measurementSystems, id: \.self) { system in
                            Text(NSLocalizedString(system.identifier, comment: "")).tag(system.identifier)
                        }
                    }
                    Picker("Energy unit", selection: $energyUnitSymbol) {
                        ForEach(UserSettings.EnergyUnit.allCases, id: \.id) { energyUnit in
                            Text(energyUnit.symbol).tag(energyUnit.symbol)
                        }
                    }
                    Picker("Power unit", selection: $powerUnitSymbol) {
                        ForEach(UserSettings.PowerUnit.allCases, id: \.id) { powerUnit in
                            Text(powerUnit.symbol).tag(powerUnit.symbol)
                        }
                    }
                    Toggle("Show energy over distance", isOn: $energyOverDistance)
                    Picker("Distance multiplier", selection: $distanceMultiplier) {
                        Text("1").tag(1)
                        Text("10").tag(10)
                        Text("100").tag(100)
                    }
                }
                
                Section(header: Text("Financial settings")) {
                    Picker("Currency", selection: $currencyIdentifier) {
                        ForEach(Locale.commonISOCurrencyCodes, id: \.self) { identifier in
                            Text(identifier).tag(identifier)
                        }
                    }
                    HStack {
                        Text("VAT rate")
                        Spacer()
                        TextField("VAT rate", value: $vatRate, format: .percent)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Display gross prices", isOn: $displayGrossPrices)
                    HStack {
                        Text("Preferred currencies: \(userSettings.preferredCurrencies.sorted().joined(separator: ", "))")
                        Button(action: {
                            showingCurrencySelector = true
                        }) {
                            Image(systemName: "pencil.circle")
                        }
                        .sheet(isPresented: $showingCurrencySelector) {
                            currencySelector()
                        }
                    }
                }
                
                Section(header: Text("Maintenance")) {
                    Button("Check for missing refunding home consumptions") {
                        checkForMissingHomeConsumptions()
                    }
                    .alert("Notice", isPresented: $showingUpdateChargingSessionsAlert) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        let message = "The following sessions have been assigned a home consumption:\n\(updatedChargingSessions.joined(separator: "\n"))"
                        Text(message)
                    }
                }
                
                Section(header: Text("Import/Export")) {
                    Button("Load sample master data") {
                        SampleMasterData.masterSampleData(in: modelContext)
                    }
                    
                    Button("Import Charging Sessions (JSON)") {
                        // First ask the user which Car to assign imports to
                        // Reset selection to default (none)
                        selectedImportCarIndex = nil
                        selectedImportCar = nil
                        showingCarPicker = true
                    }
                    .fileImporter(isPresented: $isImportingChargingSessionFile, allowedContentTypes: [UTType.json], allowsMultipleSelection: false) { result in
                        switch result {
                        case .success(let urls):
                            guard let url = urls.first else { return }
                            Task {
                                do {
                                    let report = try ChargingSessionImporter.importFromFile(url: url, into: modelContext, assignedCar: selectedImportCar)
                                    var msg = "Imported \(report.imported)/\(report.total) sessions."
                                    if report.skippedNoPlan > 0 || report.skippedDuplicate > 0 || report.failed > 0 {
                                        msg += " Skipped: \(report.skippedNoPlan) (no plan), \(report.skippedDuplicate) (duplicates), \(report.failed) (failed)."
                                    }
                                    if !report.errors.isEmpty {
                                        msg += " Errors: " + report.errors.joined(separator: "; ")
                                    }
                                    importMessage = msg
                                    showImportResult = true
                                } catch {
                                    importMessage = "Import failed: \(error)"
                                    showImportResult = true
                                }
                            }
                        case .failure(let error):
                            importMessage = "File selection failed: \(error.localizedDescription)"
                            showImportResult = true
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button("Import Home Consumptions (JSON)") {
                        isImportingHomeConsumptionFile = true
                    }
                    .fileImporter(isPresented: $isImportingHomeConsumptionFile, allowedContentTypes: [UTType.json], allowsMultipleSelection: false) { result in
                        switch result {
                        case .success(let urls):
                            guard let url = urls.first else { return }
                            Task {
                                do {
                                    let report = try HomeConsumptionImporter.importFromFile(url: url, into: modelContext)
                                    var msg = "Imported \(report.imported)/\(report.total) home consumptions."
                                    if report.skippedDuplicate > 0 || report.failed > 0 {
                                        msg += " Skipped: \(report.skippedDuplicate) (duplicates), \(report.failed) (failed)."
                                    }
                                    if !report.errors.isEmpty {
                                        msg += " Errors: " + report.errors.joined(separator: "; ")
                                    }
                                    importMessage = msg
                                    showImportResult = true
                                } catch {
                                    importMessage = "Import failed: \(error)"
                                    showImportResult = true
                                }
                            }
                        case .failure(let error):
                            importMessage = "File selection failed: \(error.localizedDescription)"
                            showImportResult = true
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button("Import Price Elements (JSON)") {
                        isImportingPriceElementFile = true
                    }
                    .fileImporter(isPresented: $isImportingPriceElementFile, allowedContentTypes: [UTType.json], allowsMultipleSelection: false) { result in
                        switch result {
                        case .success(let urls):
                            guard let url = urls.first else { return }
                            Task {
                                do {
                                    let report = try PriceElementImporter.importFromFile(url: url, into: modelContext)
                                    var msg = "Imported \(report.imported)/\(report.total) price elements."
                                    if report.skippedNoHomeConsumption > 0 || report.skippedDuplicate > 0 || report.failed > 0 {
                                        msg += " Skipped: \(report.skippedNoHomeConsumption) (no home consumption), \(report.skippedDuplicate) (duplicates), \(report.failed) (failed)."
                                    }
                                    if !report.errors.isEmpty {
                                        msg += " Errors: " + report.errors.joined(separator: "; ")
                                    }
                                    importMessage = msg
                                    showImportResult = true
                                } catch {
                                    importMessage = "Import failed: \(error)"
                                    showImportResult = true
                                }
                            }
                        case .failure(let error):
                            importMessage = "File selection failed: \(error.localizedDescription)"
                            showImportResult = true
                        }
                    }
                    .foregroundColor(.blue)
                    
                    // Export button: create a backup JSON and present share sheet so user picks destination
                    Button("Export all data (JSON)") {
                        Task {
                            do {
                                let data = try DataEncoder.export(context: modelContext)
                                let tmp = FileManager.default.temporaryDirectory
                                let iso = ISO8601DateFormatter().string(from: Date())
                                let fileURL = tmp.appendingPathComponent("clevercheck-backup-\(iso).json")
                                try data.write(to: fileURL, options: .atomic)
                                exportFileURL = fileURL
                                isSharing = true
                            } catch {
                                importMessage = "Export failed: \(error)"
                                showImportResult = true
                            }
                        }
                    }
                    .foregroundColor(.blue)
                    .sheet(isPresented: $isSharing) {
                        if let url = exportFileURL {
                            ShareSheet(activityItems: [url]) { completed, err in
                                if completed {
                                    // remove temp file after successful share
                                    do { try FileManager.default.removeItem(at: url); exportFileURL = nil } catch { print("Failed to remove temp export file: \(error)") }
                                    importMessage = "Export shared. Temporary file removed."
                                } else if let err = err {
                                    importMessage = "Share failed: \(err.localizedDescription)"
                                } else {
                                    importMessage = "Share cancelled."
                                }
                                showImportResult = true
                                isSharing = false
                            }
                        } else {
                            Text("No file to share")
                        }
                    }
                }
                
                // Car picker sheet
                .sheet(isPresented: $showingCarPicker) {
                    NavigationView {
                        Form {
                            Section(header: Text("Assign imported sessions to")) {
                                Picker("Car", selection: $selectedImportCarIndex) {
                                    Text("None (leave as in file or use plan)").tag(nil as Int?)
                                    ForEach(cars.indices, id: \.self) { idx in
                                        Text(cars[idx].description).tag(Optional(idx))
                                    }
                                }
                                .pickerStyle(.inline)
                            }
                        }
                        .navigationTitle("Select Car")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showingCarPicker = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Continue") {
                                    // Resolve selected car
                                    if let idx = selectedImportCarIndex, idx >= 0, idx < cars.count {
                                        selectedImportCar = cars[idx]
                                    } else {
                                        selectedImportCar = nil
                                    }
                                    showingCarPicker = false
                                    // Trigger file importer
                                    isImportingChargingSessionFile = true
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Danger Zone")) {
                    Button("Delete all data") {
                        showingDeleteAllAlert = true
                    }
                    .foregroundColor(.red)
                    .alert("DANGER", isPresented: $showingDeleteAllAlert) {
                        TextField("DELETE ALL", text: $confirmDeletion)
                        Button("OK", action: deleteAllData)
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("Enter 'DELETE ALL' to confirm - this cannot be undone.")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                }
            }
            .navigationDestination(for: NavigationDestination.self) { screen in
                switch screen {
                case .Cars:
                    CarsView(navigationPath: $navigationPath)
                case .Locations:
                    LocationsView(navigationPath: $navigationPath)
                case .Chargers:
                    ChargersView(navigationPath: $navigationPath)
                case .ChargingCostPlans:
                    ChargingCostPlansView(navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: CarsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewCar:
                    CarEditor(navigationPath: $navigationPath, car: nil)
                case .EditCar(car: let car):
                    CarEditor(navigationPath: $navigationPath, car: car)
                }
            }
            .navigationDestination(for: LocationsView.NavigationDestination.self) { screen in
                switch screen {
                case .NewLocation(location: let location):
                    LocationEditor(navigationPath: $navigationPath, location: location)
                case .EditLocation(location: let location):
                    LocationEditor(navigationPath: $navigationPath, location: location)
                }
            }
            .navigationDestination(for: ChargersView.NavigationDestination.self) { screen in
                switch screen {
                case .NewCharger:
                    ChargerEditor(navigationPath: $navigationPath, charger: nil)
                case .EditCharger(charger: let charger):
                    ChargerEditor(navigationPath: $navigationPath, charger: charger)
                }
            }
            .navigationDestination(for: ChargingCostPlansView.NavigationDestination.self) { screen in
                switch screen {
                case .NewPlan(let car):
                    ChargingCostPlanEditor(navigationPath: $navigationPath, plan: nil, car: car)
                case .EditPlan(plan: let plan):
                    ChargingCostPlanEditor(navigationPath: $navigationPath, plan: plan)
                }
            }
        }
        .alert("Import", isPresented: $showImportResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importMessage)
        }
    }
    
    private func checkForMissingHomeConsumptions() {
        for session in chargingSessions {
            if session.chargingCostPlan?.planType == .refunded, session.relatedHomeConsumption == nil {
                let candidates = session.possibleHomeConsumptionsRefunded(modelContext: modelContext, ignorePlan: false, ignoreDate: false)
                if let candidates, candidates.count == 1 {
                    session.relatedHomeConsumption = candidates.first!
                    updatedChargingSessions.append(session.description)
                }
            }
        }
        
        if !updatedChargingSessions.isEmpty {
            try? modelContext.save()
            showingUpdateChargingSessionsAlert = true
        } else {
            
        }
    }
    
    private func deleteAllData() {
        if confirmDeletion == "DELETE ALL" {
            modelContext.container.deleteAllData()
            try? modelContext.save()
        }
    }
    
    @ViewBuilder
    private func currencySelector() -> some View {
        VStack {
            Text("Select the currencies to be included:")
                .font(.caption)
                .padding()
            List {
                ForEach(Locale.Currency.isoCurrencies.filter{ $0.isISOCurrency }.map(\.identifier), id: \.self) { code in
                    HStack {
                        Button(action: {
                            if userSettings.preferredCurrencies.contains(where: { $0 == code }) {
                                // Remove the selected currency
                                userSettings.preferredCurrencies.removeAll(where: { $0 == code })
                            } else {
                                // Add the selected currency
                                userSettings.preferredCurrencies.append(code)
                            }
                        }) {
                            HStack {
                                if userSettings.preferredCurrencies.contains(where: { $0 == code }) {
                                    Image(systemName: "checkmark.square")
                                } else {
                                    Image(systemName: "square")
                                }
                                Text(verbatim: code)
                            }
                        }
                        
                    }
                }
            }
        }
    }
}
