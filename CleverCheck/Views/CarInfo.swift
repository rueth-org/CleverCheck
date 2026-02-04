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
    let timeBox: TimeBox
    
    var body: some View {
        DotIndicatorScrollView(tabViews: [
            VStack {
                let chargedEnergyDict = car.chargedEnergy(in: timeBox)
                let totalChargedEnergy = chargedEnergyDict.values.reduce(Measurement<UnitEnergy>(value: 0.0, unit: .kilowattHours), +)
                Text("Charged energy")
                    .font(.headline)
                    .padding(.top)
                    .padding(.horizontal)
                Text(timeBox.formattedTime)
                    .font(.subheadline)
                    .padding(.horizontal)
                    .padding(.bottom)
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
                                Text(totalChargedEnergy.converted(to: UserSettings.shared.energyUnit).formatted())
                                    .font(.headline)
                            }
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                .padding()
            },
            VStack {
                let chargingCostDict = car.chargingCost(in: timeBox)
                let totalChargingCost = chargingCostDict.values.reduce(Cost(amount: 0.0, currency: UserSettings.shared.currencyIdentifier), +)
                Text("Direct charging cost")
                    .font(.headline)
                    .padding(.top)
                    .padding(.horizontal)
                Text(timeBox.formattedTime)
                    .font(.subheadline)
                    .padding(.horizontal)
                    .padding(.bottom)
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
                                Text(totalChargingCost.converted(to: UserSettings.shared.currencyIdentifier)?.formatted() ?? "")
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
