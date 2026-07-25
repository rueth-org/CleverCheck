// swift
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

    // State to receive tap locations from the UIViewRepresentable and process them
    @State private var pendingTapLocation: CGPoint? = nil

    @State private var chargingCostData: [Car.CostData] = []
    @State private var totalChargingCost: Cost = Cost(amount: 0.0)
    @State private var specificCost: Cost = Cost(amount: 0.0)

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
    
    var comparableFuelPrice: FuelCost? {
        // Total consumption in kWh per 100km
        guard let totalConsumption = consumptionData?.totalConsumption?.consumption(energyUnit: .kilowattHours, distanceUnit: .kilometers, distanceMultiplier: 100, energyOverDistance: true) else {
            return nil
        }
        
        // Specific cost
        guard let specificCost = specificCost.converted(to: UserSettings.shared.currencyIdentifier) else {
            return nil
        }
        
        // Absolute cost per 100km
        let absoluteCostPer100km = specificCost.amount * totalConsumption.value
        
        // Reference fuel consumption in liters per 100km
        let referenceFuelConsumption = car.referenceFuelConsumption.converted(to: .litersPer100km)
        
        // Compute the comparable fuel price per liter
        let comparableFuelPricePerLiter = absoluteCostPer100km / referenceFuelConsumption.amount
        
        return FuelCost(amount: Cost(amount: comparableFuelPricePerLiter), unit: .costPerLiter)
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
        let legendItems = legendData()
        let tabViews: [AnyView] = [
            
            //
            // Charging amount bar chart
            //
            
            AnyView(
                VStack(spacing: 0) {
                    Text("Charging data")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)

                    let chargedEnergyDataPerPeriod = chargedEnergyDataPerPeriod
                    if chargedEnergyDataPerPeriod.isEmpty {
                        Text("No charging data available for this period.")
                            .italic()
                            .padding()
                        Spacer()
                    } else {
                        Chart {
                            ForEach(chargedEnergyDataPerPeriod.sorted(by: { $0.key < $1.key }), id: \.key) { pair in
                                ForEach(pair.value.sorted(by: { $0.legendLabel < $1.legendLabel }), id: \.id) { dataSet in
                                    BarMark(
                                        x: .value("End Time", pair.key),
                                        y: .value("Charged Energy", dataSet.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value)
                                    )
                                    .foregroundStyle(dataSet.displayColor.toColor())
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
                        // Let the chart expand to fill available vertical space inside this VStack
                        .frame(maxHeight: .infinity)
                        
                        // Custom legend beneath the chart (sizes to its content)
                        legend(legendItems)
                            .frame(minHeight: 0)
                    }
                }
            ),

            //
            // Consumption bar chart
            //
            
            AnyView(
                VStack(spacing: 0) {
                    Text("Consumption")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)
                    if let consumptionData, !consumptionData.consumptions.isEmpty {
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
                        .frame(maxHeight: .infinity)
                        .layoutPriority(1)
                    } else {
                        Text("No consumption data available for this period.")
                            .italic()
                            .padding()
                        Spacer()
                    }
                }
                .frame(maxHeight: .infinity)
            ),

            //
            // Charged energy pie chart
            //
            
            AnyView(
                VStack(spacing: 0) {
                    Text("Charged energy")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)
                    let chargedEnergyData = chargedEnergyData
                    if chargedEnergyData.isEmpty {
                        Text("No energy data available for this period.")
                            .italic()
                            .padding()
                        Spacer()
                    } else {
                        Chart(chargedEnergyData, id: \.id) { dataSet in
                            SectorMark(
                                angle: .value(
                                    Text(dataSet.legendLabel),
                                    dataSet.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value
                                ),
                                innerRadius: .ratio(0.6)
                            )
                            .foregroundStyle(dataSet.displayColor.toColor())
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
                        // Let the chart expand to fill available vertical space inside this VStack
                        .frame(maxHeight: .infinity)
                        
                        // Custom legend beneath the chart (sizes to its content)
                        legend(legendItems)
                            .frame(minHeight: 0)
                    }
                }
            ),

            //
            // Charging cost pie chart
            //
            
            AnyView(
                VStack(spacing: 0) {
                    Text("Charging cost")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)
                    let chargingCostData = chargingCostData
                    if chargingCostData.isEmpty {
                        Text("No charging cost data available for this period.")
                            .italic()
                            .padding()
                        Spacer()
                    } else {
                        Chart(chargingCostData, id: \.id) { dataSet in
                            SectorMark(
                                angle: .value(
                                    Text(dataSet.legendLabel),
                                    dataSet.cost.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0
                                ),
                                innerRadius: .ratio(0.6)
                            )
                            .foregroundStyle(dataSet.displayColor.toColor())
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
                        // Let the chart expand to fill available vertical space inside this VStack
                        .frame(maxHeight: .infinity)
                        
                        // Custom legend beneath the chart (sizes to its content)
                        legend(legendItems)
                            .frame(minHeight: 0)
                    }
                    
                    // Average cost per energy unit text below the chart
                    Text("Average cost per \(UserSettings.shared.energyUnit.symbol): \(specificCost.converted(to: UserSettings.shared.currencyIdentifier)?.formatted() ?? "-")")
                        .font(.subheadline)
                        .padding(.top, 4)
                    
                    // Comparable fuel price text below the chart
                    Text("Comparable fuel price: \(comparableFuelPrice?.converted(to: UserSettings.shared.fuelConsumptionUnit.fuelCostUnit).formatted() ?? "-")")
                        .font(.subheadline)
                        .padding(.top, 2)
                    let referenceFuelConsumption = car.referenceFuelConsumption
                    Text("(based on reference consumption of \(referenceFuelConsumption.amount.formatted()) \(referenceFuelConsumption.unit.symbol))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                }
            )
        ]

        return DotIndicatorScrollView(tabViews: tabViews)
            // Re-run the async task whenever the selected time box OR the
            // selected car changes so the charging cost data updates correctly
            // when the parent updates either `timeBox` or the `car`.
            // We include the car's id in the task id so switching cars triggers
            // the task to re-run and refresh `chargingCostData` and
            // `specificCost` state.
            .task(id: "\(timeBox.selectedResolution)-\(timeBox.selectedDate.timeIntervalSince1970)-\(car.id.uuidString)") {
                // Clear previous results while loading the new ones so the UI
                // shows the "no data" state or a loading state if desired.
                chargingCostData = []
                totalChargingCost = Cost(amount: 0.0)

                let result = await car.chargingCost(in: timeBox, modelContext: modelContext)
                chargingCostData = result
                totalChargingCost = result.map { $0.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? Cost(amount: 0.0) }.reduce(Cost(amount: 0.0), +)
                specificCost = await car.specificCost(in: timeBox, modelContext: modelContext) ?? Cost(amount: 0.0)
            }
    }

    fileprivate func readTappedPosition(_ proxy: ChartProxy) -> GeometryReader<some View> {
        return GeometryReader { geometry in
            ZStack {
                if let plotFrameAnchor = proxy.plotFrame {
                    let plotFrame = geometry[plotFrameAnchor]

                    // Create an id based on current x-axis keys so the UIView gets recreated
                    let chartKeyId: String = {
                        if !chargedEnergyDataPerPeriod.isEmpty {
                            return chargedEnergyDataPerPeriod.keys.sorted().joined(separator: "|")
                        } else if let consumptionData = consumptionData, !consumptionData.consumptions.isEmpty {
                            return consumptionData.consumptions.keys.sorted().joined(separator: "|")
                        } else {
                            return aggregatedEnergySums.map{ $0.timeKey }.joined(separator: "|")
                        }
                    }()

                    // TapLocationView only writes the tap point into state. We process it below
                    // in an onChange handler that runs with the current `proxy` and `geometry`.
                    TapLocationView { loc in
                        // loc.x is relative to the TapLocationView bounds (which match the plot area)
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
                            let key = timeBox.getKeysForDate(date)
                            barTapped(key.display)
                        } else if let number = proxy.value(atX: xInPlot, as: Double.self) {
                            barTapped(String(number))
                        }

                        pendingTapLocation = nil
                    }
                }
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
    
    private func legendData() -> [(String, Color)] {
        var seen = Set<String>()
        var items: [(String, Color)] = []
        for d in chargedEnergyData {
            if !seen.contains(d.legendLabel) {
                items.append((d.legendLabel, d.displayColor.toColor()))
                seen.insert(d.legendLabel)
            }
        }
        return items
    }

    @ViewBuilder
    private func legend(_ legendItems: [(String, Color)]) -> some View {
        // Minimum column width each legend cell should try to occupy.
        let minColumnWidth: CGFloat = 140

        // Use adaptive GridItem so columns are computed automatically from available width
        let columns = [GridItem(.adaptive(minimum: minColumnWidth), spacing: 12)]

        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(legendItems, id: \.0) { label, color in
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color.clear) // keeps layout predictable
    }
}
