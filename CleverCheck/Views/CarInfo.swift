//
//  CarInfo.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 03/02/2026.
//

import SwiftUI
import Charts

struct CarInfo: View {
    let car: Car
    
    var body: some View {
        DotIndicatorScrollView(tabViews: [
            VStack {
                let chargedEnergyDict = car.chargedEnergy
                Text("Charged energy")
                    .font(.headline)
                    .padding()
                Chart(chargedEnergyDict.keys.sorted(), id: \.self) { key in
                    SectorMark(
                        angle: .value(
                            Text(key),
                            chargedEnergyDict[key]!.converted(to: UserSettings.shared.energyUnit).value
                        ),
                        innerRadius: .ratio(0.6)
                    )
                    .foregroundStyle(
                        by: .value(
                            Text(key),
                            key
                        )
                    )
                    .annotation(position: .overlay) {
                        Text(chargedEnergyDict[key]!.converted(to: UserSettings.shared.energyUnit).formatted())
                            .font(.caption)
                            .foregroundColor(.black)
                            .padding(5)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(5)
                    }
                }
                .chartBackground { chartProxy in
                    GeometryReader { geometry in
                        if let anchor = chartProxy.plotFrame {
                            let frame = geometry[anchor]
                            VStack {
                                Text(car.totalChargedEnergy.converted(to: UserSettings.shared.energyUnit).formatted())
                                    .font(.headline)
                            }
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                .padding()
            },
            VStack {
                let chargingCostDict = car.chargingCost
                Text("Direct charging cost")
                    .font(.headline)
                    .padding()
                Chart(chargingCostDict.keys.sorted(), id: \.self) { key in
                    SectorMark(
                        angle: .value(
                            Text(key),
                            chargingCostDict[key]!.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0
                        ),
                        innerRadius: .ratio(0.6)
                    )
                    .foregroundStyle(
                        by: .value(
                            Text(key),
                            key
                        )
                    )
                    .annotation(position: .overlay) {
                        Text(chargingCostDict[key]!.converted(to: UserSettings.shared.currencyIdentifier)?.formatted() ?? "")
                            .font(.caption)
                            .foregroundColor(.black)
                            .padding(5)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(5)
                    }
                }
                .chartBackground { chartProxy in
                    GeometryReader { geometry in
                        if let anchor = chartProxy.plotFrame {
                            let frame = geometry[anchor]
                            VStack {
                                Text(car.totalChargingCost.converted(to: UserSettings.shared.currencyIdentifier)?.formatted() ?? "")
                                    .font(.headline)
                            }
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                .padding()
            }
        ])
    }
}
