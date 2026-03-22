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
    var location: Location
    var timeBox: TimeBox
    var chartType: ChartType
    
    // Observe UserSettings so changes to published properties cause the view to refresh
    @ObservedObject private var settings = UserSettings.shared

    @State private var showCalculation: Bool = false
    
    private var data: [Location.Data] {
        location.data(in: timeBox, useRelatedConsumption: settings.useRelatedConsumptions, modelContext: modelContext)
    }
    
    var filteredData: [Location.Data] {
        let monthKeyGrouping = UserSettings.shared.groupingDateFormatter.string(from: timeBox.referenceDate)
        return data.filter { $0.groupingKey == monthKeyGrouping }
    }
    
    var totalData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let dataSet = filteredData.filter { $0.dataType == .total }
        return data(dataSet)
    }
    
    var homeData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let dataSet = filteredData.filter { $0.dataType == .home }
        return data(dataSet)
    }
    
    var homeDiscountData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let dataSet = filteredData.filter { $0.dataType == .homeDiscount }
        return data(dataSet)
    }
    
    var homeRefundedData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let dataSet = filteredData.filter { $0.dataType == .homeRefunded }
        return data(dataSet)
    }
    
    var chargingData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let dataSet = filteredData.filter { $0.dataType == .charging }
        return data(dataSet)
    }
    
    var chargingDiscountData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let dataSet = filteredData.filter { $0.dataType == .chargingDiscount }
        return data(dataSet)
    }
    
    var chargingRefundedData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let dataSet = filteredData.filter { $0.dataType == .chargingRefunded }
        return data(dataSet)
    }
    
    var body: some View {
        let totalData = self.totalData
        let homeData = self.homeData
        let homeRefundedData = self.homeRefundedData
        let homeDiscountData = self.homeDiscountData
        let chargingData = self.chargingData
        let chargingDiscountData = self.chargingDiscountData
        let chargingRefundedData = self.chargingRefundedData
        
        let totalConsumption = totalData.consumption.converted(to: UserSettings.shared.energyUnit)
        let totalCost = totalData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? totalData.cost
        let homeConsumption = homeData.consumption.converted(to: UserSettings.shared.energyUnit)
        let homeCost = homeData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? homeData.cost
        let homeRefundedConsumption = homeRefundedData.consumption.converted(to: UserSettings.shared.energyUnit)
        let homeRefundedCost = homeRefundedData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? homeRefundedData.cost
        let homeDiscountConsumption = homeDiscountData.consumption.converted(to: UserSettings.shared.energyUnit)
        let homeDiscountCost = homeDiscountData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? homeDiscountData.cost
        let chargingConsumption = chargingData.consumption.converted(to: UserSettings.shared.energyUnit)
        let chargingCost = chargingData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? chargingData.cost
        let chargingRefundedConsumption = chargingRefundedData.consumption.converted(to: UserSettings.shared.energyUnit)
        let chargingRefundedCost = chargingRefundedData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? chargingRefundedData.cost
        let chargingDiscountConsumption = chargingDiscountData.consumption.converted(to: UserSettings.shared.energyUnit)
        let chargingDiscountCost = chargingDiscountData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? chargingDiscountData.cost
        
        waterfallChart(
            totalConsumption,
            totalCost,
            homeConsumption,
            homeCost,
            homeRefundedConsumption,
            homeRefundedCost,
            homeDiscountConsumption,
            homeDiscountCost,
            chargingConsumption,
            chargingCost,
            chargingRefundedConsumption,
            chargingRefundedCost,
            chargingDiscountConsumption,
            chargingDiscountCost
        )
        .onTapGesture {
            showCalculation = true
        }
        .sheet(isPresented: $showCalculation) {
            List {
                Section(header: HStack {
                    Image(systemName: "circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(HomeConsumption.ConsumptionType.total.color().toColor())
                    Text("This month's gross data")
                }) {
                    consumptionSummary(totalConsumption, totalCost)
                }
                
                if homeRefundedConsumption.value != 0 || homeRefundedCost.amount != 0 {
                    Section(header: HStack {
                        Image(systemName: "minus.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(HomeConsumption.ConsumptionType.homeRefunded.color().toColor())
                        Text("This month's refunded home consumption")
                    }) {
                        consumptionSummary(homeRefundedConsumption, homeRefundedCost)
                    }
                }
                
                if chargingRefundedConsumption.value != 0 || chargingRefundedCost.amount != 0 {
                    Section(header: HStack {
                        Image(systemName: "minus.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(HomeConsumption.ConsumptionType.chargingRefunded.color().toColor())
                        Text("This month's refunded charging")
                    }) {
                        consumptionSummary(chargingRefundedConsumption, chargingRefundedCost)
                    }
                }
                
                if homeRefundedConsumption.value != 0 || homeRefundedCost.amount != 0 || chargingRefundedConsumption.value != 0 || chargingRefundedCost.amount != 0 {
                    Section(header: HStack {
                        Image(systemName: "equal.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(ImagePaint(image: pattern(HomeConsumption.ConsumptionType.total.color()), scale: 0.5))
                        Text("This month's gross data considering refunding")
                    }) {
                        let refundedConsumption = homeRefundedConsumption.value + chargingRefundedConsumption.value
                        let refundedCost = homeRefundedCost.amount + chargingRefundedCost.amount
                        consumptionSummary(
                            Measurement(value: totalConsumption.value - refundedConsumption, unit: totalConsumption.unit),
                            Cost(amount: totalCost.amount + refundedCost, currency: totalCost.currency) // Plus because refunded cost is negative
                        )
                    }
                }
                
                if homeDiscountCost.amount != 0 {
                    Section(header: HStack {
                        Image(systemName: "minus.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(HomeConsumption.ConsumptionType.homeDiscount.color().toColor())
                        Text("This month's home consumption discount")
                    }) {
                        consumptionSummary(homeDiscountConsumption, homeDiscountCost)
                    }
                }
                
                if chargingDiscountCost.amount != 0 {
                    Section(header: HStack {
                        Image(systemName: "minus.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(HomeConsumption.ConsumptionType.chargingDiscount.color().toColor())
                        Text("This month's charging discount")
                    }) {
                        consumptionSummary(chargingDiscountConsumption, chargingDiscountCost)
                    }
                }
                
                Section(header: HStack {
                    Image(systemName: "minus.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(HomeConsumption.ConsumptionType.charging.color().toColor())
                    Text("This month's charging data")
                }) {
                    consumptionSummary(chargingConsumption, chargingCost)
                }
                
                Section(header: HStack {
                    Image(systemName: "equal.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(HomeConsumption.ConsumptionType.home.color().toColor())
                    Text("This month's home consumption data")
                }) {
                    consumptionSummary(homeConsumption, homeCost)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func barMark(xText: String, yText: String, yStart: Double? = nil, yEnd: Double, style: some ShapeStyle) -> some ChartContent {
        if var ys = yStart {
            var ye = yEnd
            // Ensure start <= end to avoid invisible/negative bars
            if ys > ye {
                swap(&ys, &ye)
            }
            return BarMark(
                x: .value(xText, NSLocalizedString(xText, comment: "")),
                yStart: .value(yText, ys),
                yEnd: .value(yText, ye)
            )
            .foregroundStyle(style)
            .annotation(position: .overlay, alignment: .center) {
                Text(UserSettings.shared.format(ye - ys, withSignificantDigits: 3))
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
        _ homeConsumption: Measurement<UnitEnergy>,
        _ homeCost: Cost,
        _ homeRefundedConsumption: Measurement<UnitEnergy>,
        _ homeRefundedCost: Cost,
        _ homeDiscountConsumption: Measurement<UnitEnergy>,
        _ homeDiscountCost: Cost,
        _ chargingConsumption: Measurement<UnitEnergy>,
        _ chargingCost: Cost,
        _ chargingRefundedConsumption: Measurement<UnitEnergy>,
        _ chargingRefundedCost: Cost,
        _ chargingDiscountConsumption: Measurement<UnitEnergy>,
        _ chargingDiscountCost: Cost
    ) -> some View {
        switch chartType {
        case .consumption:
            Chart {
                // The total bar, reaching from 0 to the total consumption
                barMark(
                    xText: HomeConsumption.ConsumptionType.total.rawValue,
                    yText: "Consumption",
                    yEnd: totalConsumption.value,
                    style: HomeConsumption.ConsumptionType.total.color().toColor()
                )
                
                if homeRefundedConsumption.value != 0 {
                    // Subtracting the refunded home
                    barMark(
                        xText: HomeConsumption.ConsumptionType.homeRefunded.rawValue,
                        yText: "Consumption",
                        yStart: totalConsumption.value - homeRefundedConsumption.value,
                        yEnd: totalConsumption.value,
                        style: HomeConsumption.ConsumptionType.homeRefunded.color().toColor()
                    )
                }
                
                if chargingRefundedConsumption.value != 0 {
                    // Subtracting the refunded charging
                    barMark(
                        xText: HomeConsumption.ConsumptionType.chargingRefunded.rawValue,
                        yText: "Consumption",
                        yStart: totalConsumption.value - homeRefundedConsumption.value - chargingRefundedConsumption.value,
                        yEnd: totalConsumption.value - homeRefundedConsumption.value,
                        style: HomeConsumption.ConsumptionType.chargingRefunded.color().toColor()
                    )
                }
                
                if homeRefundedConsumption.value != 0 || chargingRefundedConsumption.value != 0 {
                    // The total considering refunding bar
                    barMark(
                        xText: "Total (including refunds)",
                        yText: "Consumption",
                        yEnd: totalConsumption.value - homeRefundedConsumption.value - chargingRefundedConsumption.value,
                        style: ImagePaint(image: pattern(HomeConsumption.ConsumptionType.total.color()), scale: 0.5)
                    )
                }
                
                // Subtracting the charging (use charging color)
                barMark(
                    xText: HomeConsumption.ConsumptionType.charging.rawValue,
                    yText: "Consumption",
                    yStart: totalConsumption.value - homeRefundedConsumption.value - chargingRefundedConsumption.value - chargingConsumption.value,
                    yEnd: totalConsumption.value - homeRefundedConsumption.value - chargingRefundedConsumption.value,
                    style: HomeConsumption.ConsumptionType.charging.color().toColor()
                )
                
                // The home consumption bar
                barMark(
                    xText: HomeConsumption.ConsumptionType.home.rawValue,
                    yText: "Consumption",
                    yEnd: homeConsumption.value,
                    style: HomeConsumption.ConsumptionType.home.color().toColor()
                )
            }
            .chartYAxisLabel(UserSettings.shared.energyUnitSymbol)
        
        case .cost:
            Chart {
                // The total bar, reaching from 0 to the total cost
                barMark(
                    xText: HomeConsumption.ConsumptionType.total.rawValue,
                    yText: "Cost",
                    yEnd: totalCost.amount,
                    style: HomeConsumption.ConsumptionType.total.color().toColor()
                )
                
                if homeRefundedCost.amount != 0 {
                    // Subtracting the refunded home
                    barMark(
                        xText: HomeConsumption.ConsumptionType.homeRefunded.rawValue,
                        yText: "Cost",
                        yStart: totalCost.amount - homeRefundedCost.amount,
                        yEnd: totalCost.amount,
                        style: HomeConsumption.ConsumptionType.homeRefunded.color().toColor()
                    )
                }
                
                if chargingRefundedCost.amount != 0 {
                    // Subtracting the refunded charging
                    barMark(
                        xText: HomeConsumption.ConsumptionType.chargingRefunded.rawValue,
                        yText: "Cost",
                        yStart: totalCost.amount - homeRefundedCost.amount - chargingRefundedCost.amount,
                        yEnd: totalCost.amount - homeRefundedCost.amount,
                        style: HomeConsumption.ConsumptionType.chargingRefunded.color().toColor()
                    )
                }
                
                if homeRefundedCost.amount != 0 || chargingRefundedCost.amount != 0 {
                    // The total considering refunding bar
                    barMark(
                        xText: "Total (including refunds)",
                        yText: "Cost",
                        yEnd: totalCost.amount - homeRefundedCost.amount - chargingRefundedCost.amount,
                        style: ImagePaint(image: pattern(HomeConsumption.ConsumptionType.total.color()), scale: 0.5)
                    )
                }
                
                // Subtracting the charging discount
                if chargingDiscountCost.amount != 0 {
                    barMark(
                        xText: HomeConsumption.ConsumptionType.chargingDiscount.rawValue,
                        yText: "Cost",
                        yStart: totalCost.amount - homeRefundedCost.amount - chargingRefundedCost.amount - chargingDiscountCost.amount,
                        yEnd: totalCost.amount - homeRefundedCost.amount - chargingRefundedCost.amount,
                        style: HomeConsumption.ConsumptionType.chargingDiscount.color().toColor()
                    )
                }
                
                // Subtracting the charging (use charging color)
                barMark(
                    xText: HomeConsumption.ConsumptionType.charging.rawValue,
                    yText: "Cost",
                    yStart: totalCost.amount - homeRefundedCost.amount - chargingRefundedCost.amount - chargingDiscountCost.amount - chargingCost.amount,
                    yEnd: totalCost.amount - homeRefundedCost.amount - chargingRefundedCost.amount - chargingDiscountCost.amount,
                    style: HomeConsumption.ConsumptionType.charging.color().toColor()
                )
                
                // The home consumption bar
                barMark(
                    xText: HomeConsumption.ConsumptionType.home.rawValue,
                    yText: "Cost",
                    yEnd: homeCost.amount,
                    style: HomeConsumption.ConsumptionType.home.color().toColor()
                )
            }
            .chartYAxisLabel(UserSettings.shared.currencyIdentifier)
        }
    }
    
    private func data(_ dataSet: [Location.Data]) -> (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let consumption = dataSet.reduce(into: Measurement(value: 0, unit: UserSettings.shared.energyUnit)) { result, data in
            result = result + data.consumption
        }
        let cost = dataSet.reduce(into: Cost(amount: 0, currency: UserSettings.shared.currencyIdentifier)) { result, data in
            result += data.cost
        }
        return (consumption, cost)
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
    
    @ViewBuilder
    private func consumptionSummary(_ consumption: Measurement<UnitEnergy>, _ cost: Cost) -> some View {
        HStack {
            Text("Consumption:")
            Spacer()
            Text("\(consumption.formatted())")
                .bold()
        }
        HStack {
            Text("Cost:")
            Spacer()
            Text(cost.formatted())
                .bold()
        }
        HStack {
            Text("Cost per \(UserSettings.shared.energyUnit.symbol):")
            Spacer()
            let specificCost = Cost(
                amount: consumption.value > 0 ? cost.amount / consumption.value : 0,
                currency: cost.currency
            )
            Text("\(specificCost.formatted())")
                .bold()
        }
    }
}
