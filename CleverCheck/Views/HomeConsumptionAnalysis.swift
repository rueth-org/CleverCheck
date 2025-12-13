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
    @Binding var navigationPath: NavigationPath
    var homeConsumptions: [HomeConsumption]
    private var location: Location?
    
    @Query private var allHomeConsumptions: [HomeConsumption]
    
    var month: Date {
        homeConsumptions.first?.validUntil ?? Date()
    }
    
    var costOfMonth: Double {
        let monthKey = UserSettings.shared.groupingDateFormatter.string(from: month)
        return allHomeConsumptions.reduce(0) { partialResult, consumption in
            partialResult + consumption.totalCostForMonth(monthKey: monthKey, isGross: UserSettings.shared.displayGrossPrices)
        }
    }
    
    var grossConsumptionOfMonth: Double {
        let monthKey = UserSettings.shared.groupingDateFormatter.string(from: month)
        return allHomeConsumptions.reduce(0) { partialResult, consumption in
            partialResult + consumption.consumptionForMonth(monthKey: monthKey, includeIfIncludedElsewhere: false)
        }
    }
    
    var netConsumptionOfMonth: Double {
        let monthKey = UserSettings.shared.groupingDateFormatter.string(from: month)
        return allHomeConsumptions.reduce(0) { partialResult, consumption in
            partialResult + consumption.netConsumptionForMonth(monthKey: monthKey)
        }
    }
    
    var body: some View {
        List {
            Section(header: Text("This month's summary")) {
                Text("Location: \(location?.name ?? NSLocalizedString("All locations", comment: ""))")
                    .bold()
                HStack {
                    Text("Net Cost:")
                    Spacer()
                    Text(costOfMonth.formatted(.currency(code: UserSettings.shared.currencyCode)))
                        .bold()
                }
                HStack {
                    Text("Total Consumption:")
                    Spacer()
                    Text("\(grossConsumptionOfMonth.formatted()) \(UserSettings.shared.energyUnit.symbol)")
                        .bold()
                }
                HStack {
                    Text("Net Consumption:")
                    Spacer()
                    Text("\(netConsumptionOfMonth.formatted()) \(UserSettings.shared.energyUnit.symbol)")
                        .bold()
                }
                HStack {
                    Text("Specific Cost:")
                    Spacer()
                    let specificCost = netConsumptionOfMonth > 0 ? costOfMonth / netConsumptionOfMonth : 0
                    Text("\(specificCost.formatted(.currency(code: UserSettings.shared.currencyCode)))/\(UserSettings.shared.energyUnit.symbol)")
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
                            Text("Cost:")
                            Spacer()
                            Text(homeConsumption.totalCost(isGross: UserSettings.shared.displayGrossPrices).formatted(.currency(code: UserSettings.shared.currencyCode)))
                        }
                        HStack {
                            Text("Specific Cost:")
                            Spacer()
                            Text("\(homeConsumption.specificCost(isGross: UserSettings.shared.displayGrossPrices).formatted(.currency(code: UserSettings.shared.currencyCode)))/\(UserSettings.shared.energyUnit.symbol)")
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(month, format: UserSettings.shared.displayDateFormatInSection)
                    .font(.headline)
            }
        }
    }
    
    init(navigationPath: Binding<NavigationPath>, homeConsumptions: [HomeConsumption], location: Location? = nil) {
        self._navigationPath = navigationPath
        self.homeConsumptions = homeConsumptions
        self.location = location
        
        // Get the location from the first home consumption
        if let location {
            // Fetch all home consumptions for this location
            let locationId = location.id
            self._allHomeConsumptions = Query(filter: #Predicate<HomeConsumption> { $0.associatedLocation?.id == locationId })
        } else {
            // No location, fetch all home consumptions
            self._allHomeConsumptions = Query()
        }
    }
}
