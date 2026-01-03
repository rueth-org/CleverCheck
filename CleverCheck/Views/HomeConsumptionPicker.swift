//
//  HomeConsumptionPicker.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 03/01/2026.
//

import SwiftUI
import SwiftData

struct HomeConsumptionPicker: View {
    @Binding var isShowing: Bool
    var possibleHomeConsumptions: [HomeConsumption]?
    
    @Binding var selectedHomeConsumption: HomeConsumption?
    @Binding var ignorePlan: Bool
    @Binding var ignoreDate: Bool
    
    var body: some View {
        VStack {
            Toggle("Ignore plan", isOn: $ignorePlan)
            Toggle("Ignore date", isOn: $ignoreDate)
            Divider()
            if let possibleHomeConsumptions, !possibleHomeConsumptions.isEmpty {
                Text("Choose home consumption:")
                List(possibleHomeConsumptions, id: \.id) { consumption in
                    HStack {
                        Image(systemName: consumption == selectedHomeConsumption ? "checkmark.circle.fill" : "circle")
                            .imageScale(.large)
                            .foregroundStyle(consumption == selectedHomeConsumption ? .green : .gray)
                        Text(consumption.descriptionWithDate)
                            .onTapGesture {
                                selectedHomeConsumption = consumption
                                debugPrint("Selected consumption: \(consumption.descriptionWithDate)")
                                isShowing = false
                            }
                    }
                }
            } else {
                Text("No valid home consumption found, try to ignore date or plan.")
                    .italic()
                Spacer()
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
