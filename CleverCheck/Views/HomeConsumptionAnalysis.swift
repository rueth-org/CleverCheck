//
//  HomeConsumptionAnalysis.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 10/12/2025.
//

import SwiftUI
import SwiftData

struct HomeConsumptionAnalysis: View {
    @Environment(\.modelContext) private var modelContext
    var homeConsumptions: [HomeConsumption]
    var timeBox: TimeBox
    var data: [Location.Data]
    var location: Location
    
    var filteredData: [Location.Data] {
        let monthKeyGrouping = UserSettings.shared.groupingDateFormatter.string(from: timeBox.referenceDate)
        return data.filter { $0.groupingKey == monthKeyGrouping }
    }
    
    var totalData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let filteredData = filteredData
        let consumption = filteredData.reduce(into: Measurement(value: 0, unit: UserSettings.shared.energyUnit)) { result, data in
            result = result + data.consumption
        }
        let cost = filteredData.reduce(into: Cost(amount: 0, currency: UserSettings.shared.currencyIdentifier)) { result, data in
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
        let homeChargingConsumption = homeChargingData.consumption.converted(to: UserSettings.shared.energyUnit)
        let homeChargingCost = homeChargingData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? homeChargingData.cost
        let refundedChargingConsumption = refundedChargingData.consumption.converted(to: UserSettings.shared.energyUnit)
        let refundedChargingCost = refundedChargingData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? refundedChargingData.cost
        
        Text(timeBox.formattedTime)
            .font(.title)
            .padding(.top)
            .padding(.horizontal)
        List {
            Text("Location: \(location.name)")
                .bold()
            
            Section(header: Text("This month's gross data")) {
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
            
            Section(header: Text("This month's gross data considering refunding")) {
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
            
            Section(header: Text("This month's home consumption data")) {
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
            
            Section(header: Text("This month's charging data")) {
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
            
            Section(header: Text("This month's related refunding")) {
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
            
            Section(header: Text("Ending this month")) {
                ForEach(homeConsumptions, id: \.self) { homeConsumption in
                    VStack(alignment: .leading) {
                        Text(homeConsumption.name)
                            .font(.headline)
                        HStack {
                            Text("Consumption:")
                            Spacer()
                            Text("\(homeConsumption.consumption.converted(to: UserSettings.shared.energyUnit).value.formatted()) \(UserSettings.shared.energyUnit.symbol)")
                        }
                        HStack {
                            Text("Gross Cost:")
                            Spacer()
                            Text(homeConsumption.totalCost(
                                includingVAT: UserSettings.shared.displayGrossPrices,
                                useRelatedConsumptions: UserSettings.shared.useRelatedConsumptions
                            ).gross.formatted())
                        }
                        HStack {
                            Text("Net Cost:")
                            Spacer()
                            Text(homeConsumption.totalCost(
                                includingVAT: UserSettings.shared.displayGrossPrices,
                                useRelatedConsumptions: UserSettings.shared.useRelatedConsumptions
                            ).net.formatted())
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }
}
