//
//  ChargingViewChart.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 21/12/2025.
//

import SwiftUI
import Charts

struct ChargingViewChart: View {
    @Environment(\.modelContext) private var modelContext
    
    let car: Car
    let timeBox: TimeBox
    
    var chargedEnergyDataPerPeriod: [String: [Car.EnergyData]] {
        car.chargedEnergyPerPeriod(in: timeBox)
    }
    
    var consumptionData: ConsumptionData? {
        car.consumptionData(in: timeBox, modelContext: modelContext)
    }
    
    var chargedEnergyData: [Car.EnergyData] {
        car.chargedEnergy(in: timeBox)
    }
    
    var totalChargedEnergy: Measurement<UnitEnergy> {
        chargedEnergyData.map{ $0.chargedEnergy }.reduce(.init(value: 0.0, unit: .kilowattHours), +)
    }
    
    var chargingCostData: [Car.CostData] {
        car.chargingCost(in: timeBox)
    }
    
    var totalChargingCost: Cost {
        chargingCostData.map{ $0.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? Cost(amount: 0.0) }.reduce(Cost(amount: 0.0), +)
    }
    
    // Compute the aggregated sum per x-axis key (timeKey) depending on selectedChart.
    private var aggregatedEnergySums: [(timeKey: String, sum: Double)] {
        // Group data by timeKey (x-axis key) and sum the relevant metric
        return chargedEnergyDataPerPeriod.map { (key, values) in
            let total = values.reduce(0.0) { $0 + $1.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value }
            return (timeKey: key, sum: total)
        }
        // Keep a stable order by sorting on the key which matches how bars are laid out
        .sorted { $0.timeKey < $1.timeKey }
    }
    
    // Optional callback invoked when a bar is tapped; receives the x-axis key (End Time) as String
    var onBarTap: ((String) -> Void)? = nil
    
    var body: some View {
        let tabViews: [AnyView] = [
            AnyView(
                VStack {
                    Text("Charging data")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)
                    Chart {
                        ForEach(chargedEnergyDataPerPeriod.sorted(by: { $0.key < $1.key }), id: \.key) { pair in
                            ForEach(pair.value.sorted(by: { $0.description < $1.description }), id: \.id) { dataSet in
                                BarMark(
                                    x: .value("End Time", pair.key),
                                    y: .value("Charged Energy", dataSet.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value)
                                )
                                .foregroundStyle(
                                    by: .value(
                                        Text(dataSet.description),
                                        dataSet.description
                                    )
                                )
                            }
                        }
                        
                        // Overlay PointMarks (invisible) with annotations for the aggregated total per x-axis key
                        ForEach(aggregatedEnergySums, id: \.timeKey) { item in
                            // Use a PointMark so we can attach an annotation positioned above the stacked bars
                            PointMark(
                                x: .value("Time Period", item.timeKey),
                                y: .value("Total", item.sum)
                            )
                            .symbol(.circle)
                            .opacity(0) // hide the symbol itself
                            .annotation(position: .top, alignment: .center) {
                                // Format the sum according to the selected chart type
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
                    .chartOverlay { proxy in
                        readTappedPosition(proxy)
                    }
                }
            ),
            
            AnyView(
                VStack {
                    Text("Consumption")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)
                    if let consumptionData {
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
                                    y: .value("Consumption", consumption.value)
                                )
                                .annotation(position: .top) {
                                    Text(consumption.formattedValue)
                                        .font(.caption)
                                        .foregroundColor(.black)
                                        .padding(5)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(5)
                                }
                            }
                            
                            if let totalConsumption = consumptionData.totalConsumption?.consumption() {
                                RuleMark(y: .value("Average consumption", totalConsumption.value))
                                    .foregroundStyle(Color.red)
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                                    .annotation(position: .bottom, alignment: .leading) {
                                        Text("Ø " + totalConsumption.formattedValue)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .padding(5)
                                            .background(Color.white.opacity(0.8))
                                            .cornerRadius(5)
                                    }
                            }
                        }
                        .chartYAxisLabel(UserSettings.shared.consumptionUnitSymbol)
                        .chartOverlay { proxy in
                            readTappedPosition(proxy)
                        }
                    } else {
                        Text("No consumption data available.")
                    }
                }
            ),
            
            AnyView(
                VStack {
                    Text("Charged energy")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)
                    Chart(chargedEnergyData, id: \.id) { dataSet in
                        SectorMark(
                            angle: .value(
                                Text(dataSet.description),
                                dataSet.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value
                            ),
                            innerRadius: .ratio(0.6)
                        )
                        .foregroundStyle(
                            by: .value(
                                Text(dataSet.description),
                                dataSet.description
                            )
                        )
                        .annotation(position: .overlay) {
                            Text(dataSet.chargedEnergy.converted(to: UserSettings.shared.energyUnit).formatted())
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
                }
            ),
            
            AnyView(
                VStack {
                    Text("Direct charging cost")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)
                    Chart(chargingCostData, id: \.id) { dataSet in
                        SectorMark(
                            angle: .value(
                                Text(dataSet.description),
                                dataSet.cost.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0
                            ),
                            innerRadius: .ratio(0.6)
                        )
                        .foregroundStyle(
                            by: .value(
                                Text(dataSet.description),
                                dataSet.description
                            )
                        )
                        .annotation(position: .overlay) {
                            Text(dataSet.cost.converted(to: UserSettings.shared.currencyIdentifier)?.formatted() ?? "")
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
            )
        ]
        
        return DotIndicatorScrollView(tabViews: tabViews)
    }
    
    fileprivate func readTappedPosition(_ proxy: ChartProxy) -> GeometryReader<some View> {
        return GeometryReader { geometry in
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
                                    let key = timeBox.getKeyForDate(date)
                                    barTapped(key)
                                } else if let number = proxy.value(atX: xInPlot, as: Double.self) {
                                    barTapped(String(number))
                                }
                            }
                        }
                )
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

