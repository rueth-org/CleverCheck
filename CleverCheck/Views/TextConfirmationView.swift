//
//  TextConfirmationView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/01/2026.
//

import SwiftUI

struct TextConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    
    var proposedData: TextRecognizer
    
    @Binding var chargedEnergy: Measurement<UnitEnergy>
    @Binding var initialSOC: Double
    @Binding var enterInitialSOC: Bool
    @Binding var finalSOC: Double
    @Binding var enterFinalSOC: Bool
    
    @State private var showingReport: Bool = false
    
    @State private var chargedEnergyCandidates: [TextRecognizer.Candidate<Measurement<UnitEnergy>>]? = nil
    @State private var selectedChargedEnergy: TextRecognizer.Candidate<Measurement<UnitEnergy>>? = nil
    @State private var initialSOCCandidates: [TextRecognizer.Candidate<Double>]? = nil
    @State private var selectedInitialSOC: TextRecognizer.Candidate<Double>? = nil
    @State private var finalSOCCandidates: [TextRecognizer.Candidate<Double>]? = nil
    @State private var selectedFinalSOC: TextRecognizer.Candidate<Double>? = nil
    
    var body: some View {
        List {
            HStack {
                Text("Values identified from image")
                    .font(.headline)
                Spacer()
                Button {
                    showingReport = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
            
            Button(action: {
                if let selectedChargedEnergy {
                    chargedEnergy = selectedChargedEnergy.value
                }
                
                if let selectedInitialSOC {
                    initialSOC = selectedInitialSOC.value
                    enterInitialSOC = true
                }
                
                if let selectedFinalSOC {
                    finalSOC = selectedFinalSOC.value
                    enterFinalSOC = true
                }
                
                // Close the sheet
                dismiss()
            }) {
                Text("Take over")
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .font(.system(size: 18))
                    .padding()
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
            .background(Color.blue)
            .cornerRadius(25)
            
            if let chargedEnergyCandidates {
                Picker("Charged energy", selection: $selectedChargedEnergy) {
                    Text("Do not take over").tag(nil as TextRecognizer.Candidate<Measurement<UnitEnergy>>?)
                    ForEach(chargedEnergyCandidates, id: \.self) { data in
                        Text("\(UserSettings.shared.format(data.value.value, withSignificantDigits: 4)) kWh").tag(data)
                    }
                }
            } else {
                Text("No charged energy identified")
                    .italic()
            }
            
            if let initialSOCCandidates {
                Picker("Initial SOC", selection: $selectedInitialSOC) {
                    Text("Do not take over").tag(nil as TextRecognizer.Candidate<Double>?)
                    ForEach(initialSOCCandidates, id: \.self) { data in
                        Text(data.value, format: .percent).tag(data)
                    }
                }
            } else {
                Text("No initial SOC identified")
                    .italic()
            }
            
            if let finalSOCCandidates {
                Picker("Final SOC", selection: $selectedFinalSOC) {
                    Text("Do not take over").tag(nil as TextRecognizer.Candidate<Double>?)
                    ForEach(finalSOCCandidates, id: \.self) { data in
                        Text(data.value, format: .percent).tag(data)
                    }
                }
            } else {
                Text("No final SOC identified")
                    .italic()
            }
            
            
        }
        .onAppear {
            if !proposedData.chargedEnergy.isEmpty {
                self.chargedEnergyCandidates = proposedData.chargedEnergy.sorted()
                self.selectedChargedEnergy = self.chargedEnergyCandidates?.first
            }
            if !proposedData.initialSOC.isEmpty {
                self.initialSOCCandidates = proposedData.initialSOC.sorted()
                self.selectedInitialSOC = self.initialSOCCandidates?.first
            }
            if !proposedData.finalSOC.isEmpty {
                self.finalSOCCandidates = proposedData.finalSOC.sorted()
                self.selectedFinalSOC = self.finalSOCCandidates?.first
            }
        }
        .sheet(isPresented: $showingReport) {
            TextConfirmationReport(report: proposedData.report)
        }
    }
}
