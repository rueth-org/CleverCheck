//
//  SettingsView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/12/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    enum NavigationDestination: Hashable {
        case Cars
        case Chargers
        case Locations
        case ChargingCostPlans
    }
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var cars: [Car]
    @State private var navigationPath = NavigationPath()

    @State private var showingAlert = false
    @State private var confirmDeletion = ""
    
    // Import states
    @State private var isImportingFile: Bool = false
    @State private var importMessage: String = ""
    @State private var showImportResult: Bool = false
    @State private var showingCarPicker: Bool = false
    @State private var selectedImportCarIndex: Int? = nil
    @State private var selectedImportCar: Car? = nil

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
                
                Section(header: Text("Import")) {
                    Button("Import Charging Sessions (JSON)") {
                        // First ask the user which Car to assign imports to
                        // Reset selection to default (none)
                        selectedImportCarIndex = nil
                        selectedImportCar = nil
                        showingCarPicker = true
                    }
                    .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [UTType.json], allowsMultipleSelection: false) { result in
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
                                    isImportingFile = true
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Danger Zone")) {
                    Button("Delete all data") {
                        showingAlert = true
                    }
                    .foregroundColor(.red)
                    .alert("DANGER", isPresented: $showingAlert) {
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
    
    private func deleteAllData() {
        if confirmDeletion == "DELETE ALL" {
            modelContext.container.deleteAllData()
        }
    }
}
