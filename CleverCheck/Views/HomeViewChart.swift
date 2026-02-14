//
//  HomeViewChart.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 02/01/2026.
//

import SwiftUI
import Charts

struct HomeViewChart: View {
    var location: Location
    var timeBox: TimeBox
    
    @Binding var showHomeData: Bool
    @Binding var showChargingData: Bool

    // pending tap location relative to the TapLocationView bounds
    @State private var pendingTapLocation: CGPoint? = nil

    // Optional callback invoked when a bar is tapped; receives the x-axis key (month) as String
    var onBarTap: ((String) -> Void)? = nil

    private var filteredHomeData: [Location.Data] {
        if showHomeData && showChargingData {
            return location.data(in: timeBox)
        } else if showHomeData {
            return location.data(in: timeBox).filter { $0.dataType == .homeConsumption }
        } else if showChargingData {
            return location.data(in: timeBox).filter { $0.dataType == .charging }
        } else {
            return location.data(in: timeBox)
        }
    }
    
    var body: some View {
        // Capture filtered data once to avoid multiple computed-property evaluations
        let data = filteredHomeData
        let sortedData = data.sorted()

        // Compute aggregated sums from the single captured data set
        let aggregatedEnergySumsLocal: [(timeKey: String, sum: Double)] = {
            let grouped = Dictionary(grouping: data) { $0.timeKey }
            return grouped.map { (key, values) in
                let total = values.reduce(0.0) { $0 + $1.consumption.value }
                return (timeKey: key, sum: total)
            }
            .sorted { $0.timeKey < $1.timeKey }
        }()

        let aggregatedCostSumsLocal: [(timeKey: String, sum: Double)] = {
            let grouped = Dictionary(grouping: data) { $0.timeKey }
            return grouped.map { (key, values) in
                let total = values.reduce(0.0) { $0 + $1.cost.amount }
                return (timeKey: key, sum: total)
            }
            .sorted { $0.timeKey < $1.timeKey }
        }()

        let tabViews: [AnyView] = [
            AnyView(
                VStack {
                    Text("Consumption")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)
                    if sortedData.isEmpty {
                        Text("No consumption data available for this period.")
                            .italic()
                            .padding()
                        Spacer()
                    } else {
                        Chart {
                            ForEach(sortedData, id: \.id) { dataSet in
                                BarMark(
                                    x: .value("Month", dataSet.timeKey),
                                    y: .value("Consumption", dataSet.consumption.value)
                                )
                                .foregroundStyle(by: .value("Data Type", NSLocalizedString(dataSet.dataType.rawValue, comment: "")))
                            }
                            
                            ForEach(aggregatedEnergySumsLocal, id: \.timeKey) { item in
                                PointMark(
                                    x: .value("Month", item.timeKey),
                                    y: .value("Total", item.sum)
                                )
                                .symbol(.circle)
                                .opacity(0)
                                .annotation(position: .top, alignment: .center) {
                                    Group {
                                        Text(UserSettings.shared.format(item.sum, withSignificantDigits: 3))
                                    }
                                    .font(.caption)
                                    .foregroundColor(.black)
                                    .padding(4)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .chartYAxisLabel(UserSettings.shared.energyUnitSymbol)
                        .chartLegend(.visible)
                        .chartOverlay { proxy in
                            readTappedPosition(proxy, aggregatedSums: aggregatedEnergySumsLocal, data: data)
                        }
                    }
                }
            ),
            
            AnyView(energyChart()),
            
            AnyView(
                VStack {
                    Text("Cost")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)
                    if sortedData.isEmpty {
                        Text("No cost data available for this period.")
                            .italic()
                            .padding()
                        Spacer()
                    } else {
                        Chart {
                            ForEach(sortedData, id: \.id) { dataSet in
                                BarMark(
                                    x: .value("Month", dataSet.timeKey),
                                    y: .value("Cost", dataSet.cost.amount)
                                )
                                .foregroundStyle(by: .value("Data Type", NSLocalizedString(dataSet.dataType.rawValue, comment: "")))
                            }
                            
                            ForEach(aggregatedCostSumsLocal, id: \.timeKey) { item in
                                PointMark(
                                    x: .value("Month", item.timeKey),
                                    y: .value("Total", item.sum)
                                )
                                .symbol(.circle)
                                .opacity(0)
                                .annotation(position: .top, alignment: .center) {
                                    Group {
                                        Text(UserSettings.shared.format(item.sum, withSignificantDigits: 3))
                                    }
                                    .font(.caption)
                                    .foregroundColor(.black)
                                    .padding(4)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .chartYAxisLabel(UserSettings.shared.currencyIdentifier)
                        .chartLegend(.visible)
                        .chartOverlay { proxy in
                            readTappedPosition(proxy, aggregatedSums: aggregatedCostSumsLocal, data: data)
                        }
                    }
                }
            ),
            
            AnyView(costChart()),
            
            AnyView(HomeViewSummary(location: location, timeBox: timeBox))
        ]
                
        return DotIndicatorScrollView(tabViews: tabViews)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle("Home consumption", isOn: $showHomeData)
                            .disabled(showChargingData == false && showHomeData == true)
                        Toggle("Charging", isOn: $showChargingData)
                            .disabled(showChargingData == true && showHomeData == false)
                    } label: {
                        Label("Filter", systemImage: "slider.horizontal.3")
                    }
                }
            }
    }
    
    fileprivate func readTappedPosition(_ proxy: ChartProxy, aggregatedSums: [(timeKey: String, sum: Double)], data: [Location.Data]) -> GeometryReader<some View> {
        return GeometryReader { geometry in
            ZStack {
                if let plotFrameAnchor = proxy.plotFrame {
                    let plotFrame = geometry[plotFrameAnchor]

                    // id changes when x-axis keys or plot size change -> recreate UIView
                    let chartKeyId: String = {
                        let keys = data.map { $0.timeKey }.sorted()
                        if !keys.isEmpty {
                            return keys.joined(separator: "|")
                        } else {
                            return aggregatedSums.map { $0.timeKey }.joined(separator: "|")
                        }
                    }()

                    TapLocationView { loc in
                        // loc is relative to the TapLocationView bounds (we size it to plotFrame)
                        pendingTapLocation = loc
                    }
                    .id(chartKeyId + "_\(Int(plotFrame.size.width))_\(Int(plotFrame.size.height))")
                    .frame(width: plotFrame.size.width, height: plotFrame.size.height)
                    .position(x: plotFrame.midX, y: plotFrame.midY)
                    .onChange(of: pendingTapLocation) { _old, newLoc in
                        guard let loc = newLoc else { return }
                        let xInPlot = loc.x

                        if let key = proxy.value(atX: xInPlot, as: String.self) {
                            barTapped(key)
                        } else if let date = proxy.value(atX: xInPlot, as: Date.self) {
                            let key = timeBox.getKeyForDate(date)
                            barTapped(key)
                        } else if let number = proxy.value(atX: xInPlot, as: Double.self) {
                            barTapped(String(number))
                        }

                        pendingTapLocation = nil
                    }
                }
            }
        }
    }

    func barTapped(_ key: String) {
        debugPrint("HomeViewChart barTapped: \(key)")
        onBarTap?(key)
    }
    
    @ViewBuilder
    private func energyChart() -> some View {
        VStack {
            Text("Total consumption")
                .font(.headline)
                .padding(.top)
                .padding(.horizontal)

            // Aggregate filteredHomeData by dataType so the sector chart shows two sectors
            let unit = UserSettings.shared.energyUnit
            let grouped = Dictionary(grouping: filteredHomeData, by: { $0.dataType })
            let aggregated: [(dataType: String, sum: Double)] = grouped.map { (key, values) in
                let total = values.reduce(0.0) { acc, item in
                    acc + item.consumption.converted(to: unit).value
                }
                return (dataType: NSLocalizedString(key.rawValue, comment: ""), sum: total)
            }

            if aggregated.isEmpty {
                Text("No consumption data available for this period.")
                    .italic()
                    .padding()
                Spacer()
            } else {
                Chart(aggregated, id: \.dataType) { item in
                    SectorMark(
                        angle: .value("Energy", item.sum),
                        innerRadius: .ratio(0.6)
                    )
                    .foregroundStyle(by: .value("Data Type", item.dataType))
                    .annotation(position: .overlay) {
                        // Show the aggregated value formatted using the chosen unit
                        let measurement = Measurement(value: item.sum, unit: unit)
                        Text(measurement.formatted())
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
                                Text(filteredHomeData.map(\.consumption).reduce(.init(value: 0, unit: .kilowattHours), +).converted(to: .kilowattHours).formatted())
                                    .font(.headline)
                            }
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private func costChart() -> some View {
        VStack {
            Text("Total cost")
                .font(.headline)
                .padding(.top)
                .padding(.horizontal)

            // Aggregate filteredHomeData by dataType so the sector chart shows two sectors
            let currency = UserSettings.shared.currencyIdentifier
            let grouped = Dictionary(grouping: filteredHomeData, by: { $0.dataType })
            let aggregated: [(dataType: String, sum: Double)] = grouped.map { (key, values) in
                let total = values.reduce(0.0) { acc, item in
                    acc + (item.cost.converted(to: currency)?.amount ?? 0.0)
                }
                return (dataType: NSLocalizedString(key.rawValue, comment: ""), sum: total)
            }

            if aggregated.isEmpty {
                Text("No cost data available for this period.")
                    .italic()
                    .padding()
                Spacer()
            } else {
                Chart(aggregated, id: \.dataType) { item in
                    SectorMark(
                        angle: .value("Cost", item.sum),
                        innerRadius: .ratio(0.6)
                    )
                    .foregroundStyle(by: .value("Data Type", item.dataType))
                    .annotation(position: .overlay) {
                        // Show the aggregated value formatted using the chosen unit
                        let amount = Cost(amount: item.sum, currency: currency)
                        Text(amount.formatted())
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
                                Text(filteredHomeData.map(\.cost).reduce(.init(amount: 0, currency: currency), +).converted(to: currency)?.formatted() ?? "-")
                                    .font(.headline)
                            }
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                .padding()
            }
        }
    }
}
