//
//  ConsumptionChart.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 01/01/2026.
//

import SwiftUI
import Charts

struct ConsumptionChart: View {
    let consumptionData: ConsumptionData
    
    var body: some View {
        Chart {
            ForEach(consumptionData.consumptions.sorted(by: { $0.key < $1.key }), id: \.key) { pair in
                let consumption = pair.value.consumption(
                    energyUnit: UserSettings.shared.energyUnit,
                    distanceUnit: UserSettings.shared.distanceUnit,
                    distanceMultiplier: UserSettings.shared.distanceMultiplier,
                    energyOverDistance: UserSettings.shared.energyOverDistance
                )
                BarMark(
                    x: .value("End Time", pair.key),
                    y: .value("Charged Energy", consumption.0)
                )
                .annotation(position: .top) {
                    Text(consumption.1)
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(5)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(5)
                }
            }
        }
        .chartYAxisLabel(UserSettings.shared.consumptionUnitSymbol)
    }
}
