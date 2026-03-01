//
//  HomeViewSummary.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 25/01/2026.
//

import SwiftUI

struct HomeViewSummary: View {
    let location: Location
    let timeBox: TimeBox

    // Observe UserSettings so changes cause view refresh
    @ObservedObject private var settings = UserSettings.shared
    
    var body: some View {
        let consumedEnergy = location.consumedEnergy(in: timeBox)
        let cost = location.cost(in: timeBox, useRelatedConsumptions: settings.useRelatedConsumptions)
        
        List {
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
                    Text("Total cost per \(settings.energyUnitSymbol)")
                    Spacer()
                    Text(Cost(
                        amount: (cost.home.amount + cost.charging.amount) / max(consumedEnergy.total.converted(to: settings.energyUnit).value, 1e-12),
                        currency: settings.currencyIdentifier
                    ).formatted())
                }
            }

            Section(header: Text("Breakdown")) {
                HStack {
                    Text("Home consumption")
                    Spacer()
                    Text(Cost(amount: cost.home.amount, currency: settings.currencyIdentifier).formatted())
                }
                HStack {
                    Text("Charging")
                    Spacer()
                    Text(Cost(amount: cost.charging.amount, currency: settings.currencyIdentifier).formatted())
                }
            }
        }
    }
}
