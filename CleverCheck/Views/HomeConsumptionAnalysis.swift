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
    
    var chargingData: (consumption: Measurement<UnitEnergy>, cost: Cost) {
        let chargingData = filteredData.filter { $0.dataType == .charging }
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
        let chargingConsumption = chargingData.consumption.converted(to: UserSettings.shared.energyUnit)
        let chargingCost = chargingData.cost.converted(to: UserSettings.shared.currencyIdentifier) ?? chargingData.cost
        let refunded = location.refunded(in: timeBox, modelContext: modelContext)
        
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
                    Text("\(chargingConsumption.formatted())")
                        .bold()
                }
                HStack {
                    Text("Cost:")
                    Spacer()
                    Text(chargingCost.formatted())
                        .bold()
                }
                HStack {
                    Text("Cost per \(UserSettings.shared.energyUnit.symbol):")
                    Spacer()
                    let specificCost = Cost(
                        amount: chargingConsumption.value > 0 ? chargingCost.amount / chargingConsumption.value : 0,
                        currency: chargingCost.currency
                    )
                    Text("\(specificCost.formatted())")
                        .bold()
                }
            }
            
            Section(header: Text("This month's related refunding")) {
                HStack {
                    Text("Energy consumption:")
                    Spacer()
                    Text(refunded.consumption.formatted())
                        .bold()
                }
                HStack {
                    Text("Refunded Cost:")
                    Spacer()
                    Text(refunded.cost.formatted())
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
                                isGross: UserSettings.shared.displayGrossPrices,
                                useRelatedConsumptions: UserSettings.shared.useRelatedConsumptions
                            ).gross.formatted())
                        }
                        HStack {
                            Text("Net Cost:")
                            Spacer()
                            Text(homeConsumption.totalCost(
                                isGross: UserSettings.shared.displayGrossPrices,
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
