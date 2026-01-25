//
//  HomeViewSummary.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 25/01/2026.
//

import SwiftUI

struct HomeViewSummary: View {
    let homeData: HomeData
    
    var body: some View {
        let consumedEnergy = homeData.consumedEnergy
        let cost = homeData.cost
        
        Section(header: Text("Total")) {
            HStack {
                Text("Total energy consumption")
                Spacer()
                Text(consumedEnergy.total.formatted())
            }
            HStack {
                Text("Total cost")
                Spacer()
                Text(Cost(
                    amount: cost.charging.amount + cost.home.amount
                ).formatted())
            }
            HStack {
                Text("Total cost per \(UserSettings.shared.energyUnitSymbol)")
                Spacer()
                Text(Cost(
                    amount: (cost.charging.amount + cost.home.amount) / consumedEnergy.total.value
                ).formatted())
            }
        }
        
        Section(header: Text("Home consumption")) {
            HStack {
                Text("Home consumption")
                Spacer()
                Text(Measurement<UnitEnergy>(
                    value: consumedEnergy.total.value - consumedEnergy.charging.value,
                    unit: UserSettings.shared.energyUnit
                ).formatted())
            }
            HStack {
                Text("Home consumption cost")
                Spacer()
                Text(cost.home.formatted())
            }
            HStack {
                Text("Home consumption cost per \(UserSettings.shared.energyUnitSymbol)")
                Spacer()
                Text(Cost(
                    amount: cost.home.amount / (consumedEnergy.total.value - consumedEnergy.charging.value)
                ).formatted())
            }
        }
        
        Section(header: Text("Charging")) {
            HStack {
                Text("Charging consumption")
                Spacer()
                Text(consumedEnergy.charging.formatted())
            }
            HStack {
                Text("Charging cost")
                Spacer()
                Text(cost.charging.formatted())
            }
            
            HStack {
                Text("Charging cost per \(UserSettings.shared.energyUnitSymbol)")
                Spacer()
                Text(Cost(
                    amount: cost.charging.amount / consumedEnergy.charging.value
                ).formatted())
            }
        }
    }
}
