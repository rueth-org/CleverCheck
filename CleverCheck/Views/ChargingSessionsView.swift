//
//  ContentView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

struct ChargingSessionsView: View {
    enum NavigationDestination: Hashable {
        case NewSession(selectedCar: Car?)
        case EditSession(chargingSession: ChargingSession, selectedCar: Car?)
    }

    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @Binding var selectedCar: Car?

    @State var timeBox: TimeBox
    
    @Query private var vehicles: [Car]
    @Query private var templates: [ChargingSessionTemplate]
    
    var filteredTemplates: [ChargingSessionTemplate] {
        if let selectedCar {
            return templates.filter { $0.chargingSession?.chargingCostPlan?.car == selectedCar }
        } else {
            return templates
        }
    }

    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlert?

    @State private var showingTemplateNameAlert: Bool = false
    @State private var templateName: String = ""
    @State private var sessionForTemplate: ChargingSession?
    @State private var selectTemplate: Bool = false

    private var groupedSessions: [String: [ChargingSession]] {
        var result: [String: [ChargingSession]] = [:]
        if selectedCar == nil {
            for vehicle in vehicles {
                var chargingSessions: [ChargingSession] = []
                if let chargingCostPlans = vehicle.chargingCostPlans {
                    for chargingCostPlan in chargingCostPlans {
                        chargingSessions.append(contentsOf: chargingCostPlan.chargingSessions?.filter { session in
                            if let period = timeBox.timePeriod {
                                return period.start <= session.endTime && session.endTime <= period.end
                            } else {
                                return true
                            }
                        } ?? [])
                    }
                    result[vehicle.description] = chargingSessions.sorted(by: { $0.endTime > $1.endTime })
                }
            }
        } else {
            var chargingSessions: [ChargingSession] = []
            if let chargingCostPlans = selectedCar?.chargingCostPlans {
                for chargingCostPlan in chargingCostPlans {
                    chargingSessions.append(contentsOf: chargingCostPlan.chargingSessions?.filter { session in
                        if let period = timeBox.timePeriod {
                            return period.start <= session.endTime && session.endTime <= period.end
                        } else {
                            return true
                        }
                    } ?? [])
                }
                result[selectedCar!.description] = chargingSessions.sorted(by: { $0.endTime > $1.endTime })
            }
        }
        return result
    }

    var body: some View {
        VStack {
            TimeBoxPicker(timeBox: timeBox)
                .padding(.horizontal)
        }
        List(groupedSessions.keys.sorted(), id: \.self) { carDescription in
            Section(header: Text(carDescription)) {
                if groupedSessions[carDescription]!.isEmpty {
                    HStack {
                        Spacer()
                        Image(systemName: "bolt.fill")
                        Text(.noChargingSessionsFound)
                        Spacer()
                    }
                    .foregroundColor(.gray)
                } else {
                    ForEach(groupedSessions[carDescription]!.sorted(by: { $0.endTime > $1.endTime }), id: \.id) { chargingSession in
                        NavigationLink(value: ChargingSessionsView.NavigationDestination.EditSession(chargingSession: chargingSession, selectedCar: chargingSession.chargingCostPlan?.car)) {
                            VStack {
                                HStack {
                                    Text(chargingSession.endTime, format: Date.FormatStyle(date: .abbreviated, time: .none))
                                    Spacer()
                                    if chargingSession.finalSOC != nil {
                                        Text(chargingSession.finalSOC!.formatted(.percent))
                                    }
                                    Spacer()
                                    Text(chargingSession.chargedEnergyFormatted)
                                }
                                HStack {
                                    Text(chargingSession.chargingCostPlan?.descriptionShortNoCar ?? "Unknown plan")
                                        .font(.subheadline)
                                    Spacer()
                                    let totalChargingCost = chargingSession.totalChargingCost
                                    if totalChargingCost.amount > 0 {
                                        Text(totalChargingCost.converted(to: UserSettings.shared.currencyIdentifier)?.formatted() ?? "")
                                            .italic()
                                    }
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                if let tmpl = chargingSession.template {
                                    // remove existing template
                                    chargingSession.template = nil
                                    modelContext.delete(tmpl)
                                    try? modelContext.save()
                                } else {
                                    // mark this session as the one to save as template and show the single alert
                                    sessionForTemplate = chargingSession
                                    showingTemplateNameAlert = true
                                }
                            } label: {
                                if chargingSession.isTemplate {
                                    Label("Remove template", systemImage: "star.slash.fill")
                                } else {
                                    Label("Add template", systemImage: "star.fill")
                                }
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(for: chargingSession)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Charging Sessions")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    MenuCarSelector(selectedCar: $selectedCar, allCars: vehicles)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(selectedCar == nil ? .primary : .blue)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                addButton()
            }
        }
        // single alert for activeAlert
        .alert(
            activeAlert?.title() ?? "Notice",
            isPresented: $showingAlert,
            presenting: activeAlert
        ) { activeAlert in
            activeAlert.actionButtons()
        } message: { activeAlert in
            activeAlert.message()
        }
        // single template name alert bound to `sessionForTemplate`
        .alert("Enter template name", isPresented: $showingTemplateNameAlert) {
            TextField("Template name", text: $templateName)
            Button("OK") {
                saveAsTemplateForSelectedSession()
            }
            Button("Cancel", role: .cancel) {
                sessionForTemplate = nil
                templateName = ""
            }
        }
        .sheet(isPresented: $selectTemplate) {
            ChargingSessionTemplatePicker(navigationPath: $navigationPath, templates: templates)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium])
        }
    }

    init(
        navigationPath: Binding<NavigationPath>,
        selectedCar: Binding<Car?>,
        timeBox: TimeBox
    ) {
        self._navigationPath = navigationPath
        self._selectedCar = selectedCar
        self._timeBox = State(initialValue: timeBox)

        let predicate = #Predicate<Car> { car in
            car.isArchived == false
        }

        _vehicles = Query(
            filter: predicate,
            sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]
        )
    }

    private func addSession() {
        if vehicles.isEmpty {
            activeAlert = SimpleAlert(type: .warning(message: "Please add a car first"))
            showingAlert = true
            return
        }

        navigationPath.append(NavigationDestination.NewSession(selectedCar: selectedCar))
    }

    private func addCar() {
        navigationPath.append(CarsView.NavigationDestination.NewCar)
    }

    private func delete(for session: ChargingSession) {
        withAnimation {
            modelContext.delete(session)
        }
        try? modelContext.save()
    }

    private func saveAsTemplateForSelectedSession() {
        guard let session = sessionForTemplate else { return }
        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            activeAlert = SimpleAlert(type: .warning(message: "Template name must not be empty"))
            showingAlert = true
            return
        }

        let tmpl = ChargingSessionTemplate(name: name, chargingSession: session)
        session.template = tmpl
        try? modelContext.save()

        templateName = ""
        sessionForTemplate = nil
        showingTemplateNameAlert = false
    }
    
    @ViewBuilder
    private func addButton() -> some View {
        Button(action: {
            // Ignore
        }) {
            Image(systemName: "plus")
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                if vehicles.isEmpty {
                    addCar()
                } else if filteredTemplates.isEmpty {
                    addSession()
                } else {
                    selectTemplate = true
                }
            }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                if vehicles.isEmpty {
                    addCar()
                } else {
                    addSession()
                }
            }
        )
    }
}
