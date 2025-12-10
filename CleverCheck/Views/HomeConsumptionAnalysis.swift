//
//  HomeConsumptionAnalysis.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 10/12/2025.
//

import SwiftUI

struct HomeConsumptionAnalysis: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    
    var homeConsumptions: [HomeConsumption]
    
    var body: some View {
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
