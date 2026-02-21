//
//  ChargingSessionTemplatePicker.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 20/02/2026.
//

import SwiftUI

struct ChargingSessionTemplatePicker: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath
    
    var templates: [ChargingSessionTemplate]
    
    var body: some View {
        Text("Select template:")
            .font(.headline)
            .padding()
        if templates.isEmpty {
            Spacer()
            Text("No templates available.")
                .italic()
            Spacer()
        } else {
            List {
                ForEach(templates, id: \.self) { template in
                    Text(template.name)
                        .onTapGesture {
                            selectTemplateForSession(template)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
    
    private func selectTemplateForSession(_ template: ChargingSessionTemplate) {
        guard
            let templateSession = template.chargingSession,
            let chargingCostPlan = templateSession.chargingCostPlan,
            let selectedCar = chargingCostPlan.car
        else {
            dismiss()
            return
        }
        
        let calendar = Calendar.current
        
        var newStartTime: Date? = nil
        if let startTime = templateSession.startTime {
            // Choose the next day from Date.now(), but the same hour and minute as in startTime
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
            components.day! += 1
            components.hour! = calendar.component(.hour, from: startTime)
            components.minute! = calendar.component(.minute, from: startTime)
            newStartTime = calendar.date(from: components)!
        }
        
        // For new endTime, choose the next day from Date.now(), but the same hour and minute as in endTime
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        components.day! += 1
        components.hour! = calendar.component(.hour, from: templateSession.endTime)
        components.minute! = calendar.component(.minute, from: templateSession.endTime)
        let newEndTime = calendar.date(from: components)!
        
        let newChargingSession = ChargingSession(
            startTime: newStartTime,
            endTime: newEndTime,
            chargedEnergy: .init(value: 0.0, unit: UserSettings.shared.energyUnit),
            chargingCostPlan: chargingCostPlan,
            initialSOC: templateSession.initialSOC,
            finalSOC: templateSession.finalSOC
        )
        
        navigationPath.append(ChargingSessionsView.NavigationDestination.EditSession(chargingSession: newChargingSession, selectedCar: selectedCar))
        
        dismiss()
    }
    
    private func delete(_ template: ChargingSessionTemplate) {
        template.chargingSession = nil
        withAnimation {
            modelContext.delete(template)
            try? modelContext.save()
        }
    }
}
