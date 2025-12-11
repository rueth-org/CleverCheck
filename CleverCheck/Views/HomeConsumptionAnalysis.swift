//
//  HomeConsumptionAnalysis.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 10/12/2025.
//

import SwiftUI
import SwiftData

struct HomeConsumptionAnalysis: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    var homeConsumptions: [HomeConsumption]
    
    @Query private var allHomeConsumptions: [HomeConsumption]
    
    var month: Date {
        homeConsumptions.first?.validUntil ?? Date()
    }
    
    var body: some View {
        VStack {
            Section(header: Text("Ending this month")) {
                List {
                    ForEach(homeConsumptions, id: \.self) { homeConsumption in
                        VStack(alignment: .leading) {
                            Text(homeConsumption.name)
                                .font(.headline)
                            Text("Total Consumption: \(homeConsumption.consumption.converted(to: UserSettings.shared.energyUnit).value.formatted()) \(UserSettings.shared.energyUnit.symbol)")
                            Text("Total Cost: \(homeConsumption.totalCost(isGross: UserSettings.shared.displayGrossPrices).formatted(.currency(code: UserSettings.shared.currencyCode)))")
                            Text("Specific Cost: \(homeConsumption.specificCost(isGross: UserSettings.shared.displayGrossPrices).formatted(.currency(code: UserSettings.shared.currencyCode)))/\(UserSettings.shared.energyUnit.symbol)")
                        }
                        .padding()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(month, format: UserSettings.shared.displayDateFormatInSection)
                    .font(.headline)
            }
        }
    }
}
