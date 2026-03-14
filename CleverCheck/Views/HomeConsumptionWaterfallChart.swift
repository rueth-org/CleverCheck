//
//  HomeConsumptionAnalysis.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 10/12/2025.
//

import SwiftUI
import SwiftData
import Charts

struct HomeConsumptionWaterfallChart: View {
    enum ChartType {
        case consumption
        case cost
    }
    
    @Environment(\.modelContext) private var modelContext
    var timeBox: TimeBox
    var data: [Location.Data]
    var chartType: ChartType
    
    @State private var showCalculation: Bool = false
    
    var filteredData: [Location.Data] {
        let monthKeyGrouping = UserSettings.shared.groupingDateFormatter.string(from: timeBox.referenceDate)
        return data.filter { $0.groupingKey == monthKeyGrouping }
    }
    
    var totalData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let totalData = filteredData.filter { $0.dataType == .total }
        let consumption = totalData.reduce(into: Measurement(value: 0, unit: UserSettings.shared.energyUnit)) { result, data in
            result = result + data.consumption
        }
        let cost = totalData.reduce(into: Cost(amount: 0, currency: UserSettings.shared.currencyIdentifier)) { result, data in
            result += data.cost
        }
        return (consumption, cost)
    }
    
    var homeData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let homeData = filteredData.filter { $0.dataType == .homeConsumption }
        let consumption = homeData.reduce(into: Measurement(value: 0, unit: UserSettings.shared.energyUnit)) { result, data in
            result = result + data.consumption
        }
        let cost = homeData.reduce(into: Cost(amount: 0, currency: UserSettings.shared.currencyIdentifier)) { result, data in
            result += data.cost
        }
        return (consumption, cost)
    }
    
    var discountData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let discountData = filteredData.filter { $0.dataType == .discount }
        let consumption = discountData.reduce(into: Measurement(value: 0, unit: UserSettings.shared.energyUnit)) { result, data in
            result = result + data.consumption
        }
        let cost = discountData.reduce(into: Cost(amount: 0, currency: UserSettings.shared.currencyIdentifier)) { result, data in
            result += data.cost
        }
        return (consumption, cost)
    }
    
    var homeChargingData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let chargingData = filteredData.filter { $0.dataType == .homeCharging }
        let consumption = chargingData.reduce(into: Measurement(value: 0, unit: UserSettings.shared.energyUnit)) { result, data in
            result = result + data.consumption
        }
        let cost = chargingData.reduce(into: Cost(amount: 0, currency: UserSettings.shared.currencyIdentifier)) { result, data in
            result += data.cost
        }
        return (consumption, cost)
    }
    
    var refundedChargingData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let chargingData = filteredData.filter { $0.dataType == .refundedCharging }
        let consumption = chargingData.reduce(into: Measurement(value: 0, unit: UserSettings.shared.energyUnit)) { result, data in
            result = result + data.consumption
        }
        let cost = chargingData.reduce(into: Cost(amount: 0, currency: UserSettings.shared.currencyIdentifier)) { result, data in
            result += data.cost
        }
        return (consumption, cost)
    }
    
    var body: some View {
        let totalConsumption = totalData.consumption.converted(to: UserSettings.shared.energyUnit)
        let totalCost = totalData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? totalData.cost
        let homeConsumption = homeData.consumption.converted(to: UserSettings.shared.energyUnit)
        let homeCost = homeData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? homeData.cost
        let discountConsumption = discountData.consumption.converted(to: UserSettings.shared.energyUnit)
        let discountCost = discountData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? discountData.cost
        let homeChargingConsumption = homeChargingData.consumption.converted(to: UserSettings.shared.energyUnit)
        let homeChargingCost = homeChargingData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? homeChargingData.cost
        let refundedChargingConsumption = refundedChargingData.consumption.converted(to: UserSettings.shared.energyUnit)
        let refundedChargingCost = refundedChargingData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? refundedChargingData.cost
        
        waterfallChart(
            totalConsumption,
            totalCost,
            refundedChargingConsumption,
            refundedChargingCost,
            discountCost,
            homeChargingConsumption,
            homeChargingCost,
            homeConsumption,
            homeCost
        )
        .onTapGesture {
            showCalculation = true
        }
        .sheet(isPresented: $showCalculation) {
            List {
                Section(header: HStack {
                    Image(systemName: "circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(Location.DataType.total.color().toColor())
                    Text("This month's gross data")
                }) {
                    HStack {
                        Text("Consumption:")
                        Spacer()
                        Text("\(totalConsumption.formatted())")
                            .bold()
                    }
                    HStack {
                        Text("Cost:")
                        Spacer()
                        Text(totalCost.formatted())
                            .bold()
                    }
                    HStack {
                        Text("Cost per \(UserSettings.shared.energyUnit.symbol):")
                        Spacer()
                        let specificCost = Cost(
                            amount: totalConsumption.value > 0 ? totalCost.amount / totalConsumption.value : 0,
                            currency: totalCost.currency
                        )
                        Text("\(specificCost.formatted())")
                            .bold()
                    }
                }
                
                Section(header: HStack {
                    Image(systemName: "minus.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(Location.DataType.refundedCharging.color().toColor())
                    Text("This month's related refunding")
                }) {
                    HStack {
                        Text("Consumption:")
                        Spacer()
                        Text("\(refundedChargingConsumption.formatted())")
                            .bold()
                    }
                    HStack {
                        Text("Cost:")
                        Spacer()
                        Text(refundedChargingCost.formatted())
                            .bold()
                    }
                    HStack {
                        Text("Cost per \(UserSettings.shared.energyUnit.symbol):")
                        Spacer()
                        let specificCost = Cost(
                            amount: refundedChargingConsumption.value > 0 ? refundedChargingCost.amount / refundedChargingConsumption.value : 0,
                            currency: refundedChargingCost.currency
                        )
                        Text("\(specificCost.formatted())")
                            .bold()
                    }
                }
                
                Section(header: HStack {
                    Image(systemName: "equal.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(ImagePaint(image: pattern(Location.DataType.total.color()), scale: 0.5))
                    Text("This month's gross data considering refunding")
                }) {
                    HStack {
                        Text("Consumption:")
                        Spacer()
                        Text("\((totalConsumption - refundedChargingConsumption).formatted())")
                            .bold()
                    }
                    HStack {
                        Text("Cost:")
                        Spacer()
                        Text((totalCost - refundedChargingCost).formatted())
                            .bold()
                    }
                    HStack {
                        Text("Cost per \(UserSettings.shared.energyUnit.symbol):")
                        Spacer()
                        let specificCost = Cost(
                            amount: (totalConsumption - refundedChargingConsumption).value > 0 ? (totalCost - refundedChargingCost).amount / (totalConsumption - refundedChargingConsumption).value : 0,
                            currency: totalCost.currency
                        )
                        Text("\(specificCost.formatted())")
                            .bold()
                    }
                }
                
                if discountCost.amount != 0 {
                    Section(header: HStack {
                        Image(systemName: "minus.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(Location.DataType.discount.color().toColor())
                        Text("This month's charging discount")
                    }) {
                        HStack {
                            Text("Consumption:")
                            Spacer()
                            Text("(\(discountConsumption.formatted()))")
                                .bold()
                        }
                        HStack {
                            Text("Cost:")
                            Spacer()
                            Text(discountCost.formatted())
                                .bold()
                        }
                        HStack {
                            Text("Cost per \(UserSettings.shared.energyUnit.symbol):")
                            Spacer()
                            let specificCost = Cost(
                                amount: discountConsumption.value > 0 ? discountCost.amount / discountConsumption.value : 0,
                                currency: discountCost.currency
                            )
                            Text("\(specificCost.formatted())")
                                .bold()
                        }
                    }
                }
                
                Section(header: HStack {
                    Image(systemName: "minus.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(Location.DataType.homeCharging.color().toColor())
                    Text("This month's charging data")
                }) {
                    HStack {
                        Text("Consumption:")
                        Spacer()
                        Text("\(homeChargingConsumption.formatted())")
                            .bold()
                    }
                    HStack {
                        Text("Cost:")
                        Spacer()
                        Text(homeChargingCost.formatted())
                            .bold()
                    }
                    HStack {
                        Text("Cost per \(UserSettings.shared.energyUnit.symbol):")
                        Spacer()
                        let specificCost = Cost(
                            amount: homeChargingConsumption.value > 0 ? homeChargingCost.amount / homeChargingConsumption.value : 0,
                            currency: homeChargingCost.currency
                        )
                        Text("\(specificCost.formatted())")
                            .bold()
                    }
                }
                
                Section(header: HStack {
                    Image(systemName: "equal.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(Location.DataType.homeConsumption.color().toColor())
                    Text("This month's home consumption data")
                }) {
                    HStack {
                        Text("Consumption:")
                        Spacer()
                        Text("\(homeConsumption.formatted())")
                            .bold()
                    }
                    HStack {
                        Text("Cost:")
                        Spacer()
                        Text(homeCost.formatted())
                            .bold()
                    }
                    HStack {
                        Text("Cost per \(UserSettings.shared.energyUnit.symbol):")
                        Spacer()
                        let specificCost = Cost(
                            amount: homeConsumption.value > 0 ? homeCost.amount / homeConsumption.value : 0,
                            currency: homeCost.currency
                        )
                        Text("\(specificCost.formatted())")
                            .bold()
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func barMark(xText: String, yText: String, yStart: Double? = nil, yEnd: Double, style: some ShapeStyle) -> some ChartContent {
        if let yStart {
            return BarMark(
                x: .value(xText, NSLocalizedString(xText, comment: "")),
                yStart: .value(yText, yStart),
                yEnd: .value(yText, yEnd)
            )
            .foregroundStyle(style)
            .annotation(position: .overlay, alignment: .center) {
                Text(UserSettings.shared.format(yEnd - yStart, withSignificantDigits: 3))
                    .font(.caption)
                    .foregroundColor(.black)
                    .padding(4)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(6)
            }
        } else {
            return BarMark(
                x: .value(xText, NSLocalizedString(xText, comment: "")),
                y: .value(yText, yEnd)
            )
            .foregroundStyle(style)
            .annotation(position: .top, alignment: .center) {
                Text(UserSettings.shared.format(yEnd, withSignificantDigits: 3))
                    .font(.caption)
                    .foregroundColor(.black)
                    .padding(4)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(6)
            }
        }
    }
    
    @ViewBuilder
    private func waterfallChart(
        _ totalConsumption: Measurement<UnitEnergy>,
        _ totalCost: Cost,
        _ refundedChargingConsumption: Measurement<UnitEnergy>,
        _ refundedChargingCost: Cost,
        _ discountCost: Cost,
        _ homeChargingConsumption: Measurement<UnitEnergy>,
        _ homeChargingCost: Cost,
        _ homeConsumption: Measurement<UnitEnergy>,
        _ homeCost: Cost
    ) -> some View {
        switch chartType {
        case .consumption:
            Chart {
                // The total bar, reaching from 0 to the total consumption
                barMark(
                    xText: Location.DataType.total.rawValue,
                    yText: "Consumption",
                    yEnd: totalConsumption.value,
                    style: Location.DataType.total.color().toColor()
                )
                
                if refundedChargingConsumption.value > 0 {
                    // Subtracting the refunded charging, i.e., the top of the bar needs to be at the level of the total
                    barMark(
                        xText: Location.DataType.refundedCharging.rawValue,
                        yText: "Consumption",
                        yStart: totalConsumption.value - refundedChargingConsumption.value,
                        yEnd: totalConsumption.value,
                        style: Location.DataType.refundedCharging.color().toColor()
                    )
                    
                    // The total considering refunding bar, reaching from 0 to the total consumption - refunded charging consumption
                    barMark(
                        xText: "Total (including refunds)",
                        yText: "Consumption",
                        yEnd: totalConsumption.value - refundedChargingConsumption.value,
                        style: ImagePaint(image: pattern(Location.DataType.total.color()), scale: 0.5)
                    )
                }
                
                // Subtracting the home charging, i.e., the top of the bar needs to be at the level of the total considering refunding
                barMark(
                    xText: Location.DataType.homeCharging.rawValue,
                    yText: "Consumption",
                    yStart: totalConsumption.value - refundedChargingConsumption.value - homeChargingConsumption.value,
                    yEnd: totalConsumption.value - refundedChargingConsumption.value,
                    style: Location.DataType.homeCharging.color().toColor()
                )
                
                // The home consumption bar
                barMark(
                    xText: Location.DataType.homeConsumption.rawValue,
                    yText: "Consumption",
                    yEnd: homeConsumption.value,
                    style: Location.DataType.homeConsumption.color().toColor()
                )
            }
            .chartYAxisLabel(UserSettings.shared.energyUnitSymbol)
        
        case .cost:
            Chart {
                // The total bar, reaching from 0 to the total cost
                barMark(
                    xText: Location.DataType.total.rawValue,
                    yText: "Cost",
                    yEnd: totalCost.amount,
                    style: Location.DataType.total.color().toColor()
                )
                
                if refundedChargingCost.amount > 0 {
                    // Subtracting the refunded charging, i.e., the top of the bar needs to be at the level of the total
                    barMark(
                        xText: Location.DataType.refundedCharging.rawValue,
                        yText: "Cost",
                        yStart: totalCost.amount - refundedChargingCost.amount,
                        yEnd: totalCost.amount,
                        style: Location.DataType.refundedCharging.color().toColor()
                    )
                    
                    // The total considering refunding bar, reaching from 0 to the total cost - refunded charging cost
                    barMark(
                        xText: "Total (including refunds)",
                        yText: "Cost",
                        yEnd: totalCost.amount - refundedChargingCost.amount,
                        style: ImagePaint(image: pattern(Location.DataType.total.color()), scale: 0.5)
                    )
                }
                
                // Subtracting the discount
                if discountCost.amount > 0 {
                    barMark(
                        xText: Location.DataType.discount.rawValue,
                        yText: "Cost",
                        yStart: totalCost.amount - refundedChargingCost.amount - discountCost.amount,
                        yEnd: totalCost.amount - refundedChargingCost.amount,
                        style: Location.DataType.discount.color().toColor()
                    )
                }
                
                // Subtracting the home charging, i.e., the top of the bar needs to be at the level of the total considering refunding
                barMark(
                    xText: Location.DataType.homeCharging.rawValue,
                    yText: "Cost",
                    yStart: totalCost.amount - refundedChargingCost.amount - discountCost.amount - homeChargingCost.amount,
                    yEnd: totalCost.amount - refundedChargingCost.amount - discountCost.amount,
                    style: Location.DataType.homeCharging.color().toColor()
                )
                
                // The home cost bar
                barMark(
                    xText: Location.DataType.homeConsumption.rawValue,
                    yText: "Cost",
                    yEnd: homeCost.amount,
                    style: Location.DataType.homeConsumption.color().toColor()
                )
            }
            .chartYAxisLabel(UserSettings.shared.currencyIdentifier)
        }
    }
    
    // Create a striped pattern image
    private func pattern(_ color: DisplayColor) -> Image {
        Image(size: .init(width: 40, height: 30)) { gc in
            gc.fill(Path(CGRect(x: 0, y: 0, width: 40, height: 30)), with: .color(.white.opacity(0.3)))
            
            func stroke(from: CGPoint, to: CGPoint) {
                gc.stroke(Path { p in
                    p.move(to: from)
                    p.addLine(to: to)
                }, with: .color(color.toColor()), style: .init(lineWidth: 20, lineCap: .square))
            }
            
            stroke(from: .init(x: 40, y: 0), to: .init(x: 0, y: 30))
            stroke(from: .init(x: 40, y: -30), to: .zero)
            stroke(from: .init(x: 40, y: 30), to: .init(x: 0, y: 60))
        }
    }
}

