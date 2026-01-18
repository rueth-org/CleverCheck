//
//  HomeViewChart.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 02/01/2026.
//

import SwiftUI
import Charts

struct HomeViewChart: View {
    var homeData: HomeData
    var selectedChart: HomeView.Chart

    @Binding var showHomeData: Bool
    @Binding var showChargingData: Bool
    
    var yAxisLabel: String {
        switch selectedChart {
        case .energy:
            UserSettings.shared.energyUnitSymbol
        case .cost:
            UserSettings.shared.currencyIdentifier
        }
    }
    
    // Optional callback invoked when a bar is tapped; receives the x-axis key (month) as String
    var onBarTap: ((String) -> Void)? = nil
    
    private var filteredHomeData: [HomeData.Data] {
        if showHomeData && showChargingData {
            return homeData.data
        } else if showHomeData {
            return homeData.data.filter { $0.dataType == .homeConsumption }
        } else if showChargingData {
            return homeData.data.filter { $0.dataType == .charging }
        } else {
            return homeData.data
        }
    }

    // Compute the aggregated sum per x-axis key (timeKey) depending on selectedChart.
    private var aggregatedSums: [(timeKey: String, sum: Double)] {
        // Group data by timeKey (x-axis key) and sum the relevant metric
        let grouped = Dictionary(grouping: filteredHomeData) { $0.timeKey }
        return grouped.map { (key, values) in
            let total: Double
            switch selectedChart {
            case .energy:
                total = values.reduce(0.0) { $0 + $1.consumption.value }
            case .cost:
                total = values.reduce(0.0) { $0 + $1.cost.amount }
            }
            return (timeKey: key, sum: total)
        }
        // Keep a stable order by sorting on the key which matches how bars are laid out
        .sorted { $0.timeKey < $1.timeKey }
    }
    
    var body: some View {
        Chart {
            switch selectedChart {
            case .energy:
                ForEach(filteredHomeData.sorted(), id: \.id) { dataSet in
                    BarMark(
                        x: .value("Month", dataSet.timeKey),
                        y: .value("Consumption", dataSet.consumption.value)
                    )
                    .foregroundStyle(by: .value("Data Type", NSLocalizedString(dataSet.dataType.rawValue, comment: "")))
                }
            case .cost:
                ForEach(filteredHomeData.sorted(), id: \.id) { dataSet in
                    BarMark(
                        x: .value("Month", dataSet.timeKey),
                        y: .value("Cost", dataSet.cost.amount)
                    )
                    .foregroundStyle(by: .value("Data Type", NSLocalizedString(dataSet.dataType.rawValue, comment: "")))
                }
            }

            // Overlay PointMarks (invisible) with annotations for the aggregated total per x-axis key
            ForEach(aggregatedSums, id: \.timeKey) { item in
                // Use a PointMark so we can attach an annotation positioned above the stacked bars
                PointMark(
                    x: .value("Month", item.timeKey),
                    y: .value("Total", item.sum)
                )
                .symbol(.circle)
                .opacity(0) // hide the symbol itself
                .annotation(position: .top, alignment: .center) {
                    // Format the sum according to the selected chart type
                    Group {
                        switch selectedChart {
                        case .energy:
                            Text(UserSettings.shared.format(item.sum, withSignificantDigits: 3))
                        case .cost:
                            Text(UserSettings.shared.formatAsCurrencyNoSymbol(item.sum))
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.black)
                    .padding(4)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(6)
                }
            }
        }
        .frame(minHeight: 200)
        .chartYAxisLabel(yAxisLabel)
        .chartLegend(.visible)
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
                                        let key = homeData.timeBox.getKeyForDate(date)
                                        barTapped(key)
                                    } else if let number = proxy.value(atX: xInPlot, as: Double.self) {
                                        barTapped(String(number))
                                    }
                                }
                            }
                    )
            }
        }
        
        Toggle("Home consumption", isOn: $showHomeData)
            .disabled(showChargingData == false && showHomeData == true)
        Toggle("Charging", isOn: $showChargingData)
            .disabled(showChargingData == true && showHomeData == false)
    }
    
    // Called when a bar is tapped. String is the "End Time" key from the x-axis.
    func barTapped(_ key: String) {
        // Debug print for development to verify taps
        debugPrint("ChargingViewChart barTapped: \(key)")
        // Forward to external observer if provided.
        onBarTap?(key)
    }
}

