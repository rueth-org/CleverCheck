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
    var homeConsumptions: [HomeConsumption]
    var timeBox: TimeBox
    var location: Location
    
    @Query private var homeConsumptionsForLocation: [HomeConsumption]
    @Query private var allPlans: [ChargingCostPlan]
    
    var body: some View {
        let cost = location.cost(in: timeBox, useRelatedConsumptions: UserSettings.shared.useRelatedConsumptions)
        let consumption = location.consumedEnergy(in: timeBox)
        let refunded = location.refunded(in: timeBox, modelContext: modelContext)
        Text(timeBox.formattedTime)
            .font(.title)
            .padding(.top)
            .padding(.horizontal)
        List {
            Text("Location: \(location.name)")
                .bold()
            
            Section(header: Text("This month's gross data")) {
                HStack {
                    Text("Consumption:")
                    Spacer()
                    Text("\(consumption.total.formatted())")
                        .bold()
                }
                HStack {
                    Text("Cost:")
                    Spacer()
                    Text((cost.home + cost.charging).formatted())
                        .bold()
                }
                HStack {
                    Text("Cost per \(UserSettings.shared.energyUnit.symbol):")
                    Spacer()
                    let specificCost = Cost(amount:
                        consumption.total.value > 0 ? (cost.home + cost.charging).amount / consumption.total.converted(to: UserSettings.shared.energyUnit).value : 0
                    )
                    Text("\(specificCost.formatted())")
                        .bold()
                }
            }
            
            Section(header: Text("This month's home consumption data")) {
                let homeConsumption = consumption.total - consumption.charging
                HStack {
                    Text("Consumption:")
                    Spacer()
                    Text("\(homeConsumption.formatted())")
                        .bold()
                }
                HStack {
                    Text("Cost:")
                    Spacer()
                    Text(cost.home.formatted())
                        .bold()
                }
                HStack {
                    Text("Cost per \(UserSettings.shared.energyUnit.symbol):")
                    Spacer()
                    let specificCost = Cost(amount:
                        homeConsumption.value > 0 ? cost.home.amount / homeConsumption.converted(to: UserSettings.shared.energyUnit).value : 0
                    )
                    Text("\(specificCost.formatted())")
                        .bold()
                }
            }
            
            Section(header: Text("This month's charging data")) {
                HStack {
                    Text("Consumption:")
                    Spacer()
                    Text("\(consumption.charging.formatted())")
                        .bold()
                }
                HStack {
                    Text("Cost:")
                    Spacer()
                    Text(cost.charging.formatted())
                        .bold()
                }
                HStack {
                    Text("Cost per \(UserSettings.shared.energyUnit.symbol):")
                    Spacer()
                    let specificCost = Cost(amount:
                        consumption.charging.value > 0 ? cost.charging.amount / consumption.charging.converted(to: UserSettings.shared.energyUnit).value : 0
                    )
                    Text("\(specificCost.formatted())")
                        .bold()
                }
            }
            
            Section(header: Text("This month's related refunding")) {
                HStack {
                    Text("Energy consumption:")
                    Spacer()
                    Text(refunded.consumption.formatted())
                        .bold()
                }
                HStack {
                    Text("Refunded Cost:")
                    Spacer()
                    Text(refunded.cost.formatted())
                        .bold()
                }
            }
            
            Section(header: Text("Ending this month")) {
                ForEach(homeConsumptions, id: \.self) { homeConsumption in
                    VStack(alignment: .leading) {
                        Text(homeConsumption.name)
                            .font(.headline)
                        HStack {
                            Text("Consumption:")
                            Spacer()
                            Text("\(homeConsumption.consumption.converted(to: UserSettings.shared.energyUnit).value.formatted()) \(UserSettings.shared.energyUnit.symbol)")
                        }
                        HStack {
                            Text("Gross Cost:")
                            Spacer()
                            Text(homeConsumption.totalCost(
                                isGross: UserSettings.shared.displayGrossPrices,
                                useRelatedConsumptions: UserSettings.shared.useRelatedConsumptions
                            ).gross.formatted())
                        }
                        HStack {
                            Text("Net Cost:")
                            Spacer()
                            Text(homeConsumption.totalCost(
                                isGross: UserSettings.shared.displayGrossPrices,
                                useRelatedConsumptions: UserSettings.shared.useRelatedConsumptions
                            ).net.formatted())
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }
}
