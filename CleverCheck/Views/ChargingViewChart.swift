//
//  ChargingViewChart.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 21/12/2025.
//

import SwiftUI
import Charts

struct ChargingViewChart: View {
    var chargingData: ChargingData
    var selectedChart: ChargingView.Chart
    
    var yAxisLabel: String {
        switch selectedChart {
        case .charging:
            UserSettings.shared.energyUnitSymbol
        case .consumption:
            UserSettings.shared.consumptionUnitSymbol
        }
    }
    
    // Optional callback invoked when a bar is tapped; receives the x-axis key (End Time) as String
    var onBarTap: ((String) -> Void)? = nil
    
    var body: some View {
        Chart {
            switch selectedChart {
            case .charging:
                ForEach(chargingData.chargedEnergy.sorted(by: { $0.key < $1.key }), id: \.key) { pair in
                    BarMark(
                        x: .value("End Time", pair.key),
                        y: .value("Charged Energy", pair.value)
                    )
                    .annotation(position: .top) {
                        Text(UserSettings.shared.format(pair.value, withSignificantDigits: 3))
                            .font(.caption)
                            .foregroundColor(.black)
                            .padding(5)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(5)
                    }
                }
            case .consumption:
                if let consumptionData = chargingData.consumptionData {
                    ForEach(consumptionData.consumptions.sorted(by: { $0.key < $1.key }), id: \.key) { pair in
                        let consumption = pair.value.consumption(
                            energyUnit: UserSettings.shared.energyUnit,
                            distanceUnit: UserSettings.shared.distanceUnit,
                            distanceMultiplier: UserSettings.shared.distanceMultiplier,
                            energyOverDistance: UserSettings.shared.energyOverDistance
                        )
                        BarMark(
                            x: .value("End Time", pair.key),
                            y: .value("Consumption", consumption.0)
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
            }
            
        }
        .chartYAxisLabel(yAxisLabel)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                // Invisible layer that captures taps over the chart's plot area
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                if let plotFrameAnchor = proxy.plotFrame {
                                    let plotFrame = geometry[plotFrameAnchor]
                                    let location = value.location
                                    // location is in the overlay's coordinate space (same as geometry),
                                    // so subtract the plot area's origin to get x inside the plot area.
                                    let xInPlot = location.x - plotFrame.origin.x

                                    // Ask the proxy for the underlying x-axis value at that x position.
                                    // The value might be a String (our current chart uses String keys),
                                    // but handle Date and Number too.
                                    if let key = proxy.value(atX: xInPlot, as: String.self) {
                                        barTapped(key)
                                    } else if let date = proxy.value(atX: xInPlot, as: Date.self) {
                                        let key = chargingData.timeBox.getKeyForDate(date)
                                        barTapped(key)
                                    } else if let number = proxy.value(atX: xInPlot, as: Double.self) {
                                        barTapped(String(number))
                                    }
                                }
                            }
                    )
            }
        }
    }

    // Called when a bar is tapped. String is the "End Time" key from the x-axis.
    func barTapped(_ key: String) {
        // Debug print for development to verify taps
        debugPrint("ChargingViewChart barTapped: \(key)")
        // Forward to external observer if provided.
        onBarTap?(key)
    }
}
