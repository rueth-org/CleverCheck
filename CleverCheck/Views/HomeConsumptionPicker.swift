//
//  HomeConsumptionPicker.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 03/01/2026.
//

import SwiftUI
import SwiftData

struct HomeConsumptionPicker: View {
    @Environment(\.dismiss) var dismiss
    var possibleHomeConsumptions: [HomeConsumption]?
    
    @Binding var selectedHomeConsumption: HomeConsumption?
    @Binding var chooseLater: Bool
    @Binding var ignorePlan: Bool
    @Binding var ignoreDate: Bool
    
    var body: some View {
        VStack {
            Toggle("Ignore plan", isOn: $ignorePlan)
            Toggle("Ignore date", isOn: $ignoreDate)
            Divider()
            Text("Choose home consumption:")
                .font(.headline)
            List {
                HStack {
                    Image(systemName: selectedHomeConsumption == nil ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(selectedHomeConsumption == nil ? .green : .gray)
                    Text("Choose later")
                        .onTapGesture {
                            selectedHomeConsumption = nil
                            chooseLater = true
                        }
                }
                if let possibleHomeConsumptions, !possibleHomeConsumptions.isEmpty {
                    ForEach(possibleHomeConsumptions, id: \.id) { consumption in
                        HStack {
                            Image(systemName: consumption == selectedHomeConsumption ? "checkmark.circle.fill" : "circle")
                                .imageScale(.large)
                                .foregroundStyle(consumption == selectedHomeConsumption ? .green : .gray)
                            Text(consumption.descriptionWithDate)
                                .onTapGesture {
                                    selectedHomeConsumption = consumption
                                    dismiss()
                                }
                        }
                    }
                } else {
                    Text("No valid home consumption found, try to ignore date or plan.")
                        .italic()
                }
            }
        }
        .padding()
        .onAppear {
            if selectedHomeConsumption == nil {
                if let possibleHomeConsumptions, possibleHomeConsumptions.count == 1 {
                    selectedHomeConsumption = possibleHomeConsumptions.first!
                }
            }
        }
    }
}
