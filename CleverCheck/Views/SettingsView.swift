//
//  SettingsView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/12/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

#if canImport(UIKit)
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

#elseif canImport(AppKit)
import AppKit

struct MacSharePicker: NSViewRepresentable {
    let items: [Any]
    @Binding var isPresented: Bool
    let completion: ((Bool, Error?) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: items)
            picker.delegate = context.coordinator
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class Coordinator: NSObject, NSSharingServicePickerDelegate, NSSharingServiceDelegate {
        let parent: MacSharePicker
        init(_ parent: MacSharePicker) { self.parent = parent }

        func sharingServicePicker(_ picker: NSSharingServicePicker, delegateFor item: Any) -> NSSharingServiceDelegate? {
            return self
        }

        func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
            parent.completion?(true, nil)
            DispatchQueue.main.async { parent.isPresented = false }
        }

        func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
            parent.completion?(false, error)
            DispatchQueue.main.async { parent.isPresented = false }
        }
    }
}
#endif

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
                            #if canImport(UIKit)
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
                            #elseif canImport(AppKit)
                            MacSharePicker(items: [url], isPresented: $isSharing) { completed, err in
                                if completed {
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
                            #else
                            Text("Sharing not supported on this platform")
                            #endif
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
            try? modelContext.save()
        }
    }
}
