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
    private var location: Location?
    
    @Query private var homeConsumptionsForLocation: [HomeConsumption]
    @Query private var allPlans: [ChargingCostPlan]
    
    var month: Date {
        homeConsumptions.first?.validUntil ?? Date()
    }
    
    var costOfMonth: (gross: Double, net: Double) {
        let monthKey = UserSettings.shared.groupingDateFormatter.string(from: month)
        let grossCost = homeConsumptionsForLocation.reduce(0) { partialResult, consumption in
            partialResult + consumption.totalCostForMonth(monthKey: monthKey, isGross: UserSettings.shared.displayGrossPrices).gross
        }
        let netCost = homeConsumptionsForLocation.reduce(0) { partialResult, consumption in
            partialResult + consumption.totalCostForMonth(monthKey: monthKey, isGross: UserSettings.shared.displayGrossPrices).net
        }
        return (gross: grossCost, net: netCost)
    }
    
    var refundedCostOfMonth: (Measurement<UnitEnergy>, Double) {
        if let location {
            // Filter plans by type refunded
            let refundedPlans = allPlans.filter { $0.planType == .refunded }
            
            // Get all plans, which are child plans of
            let allRelatedPlans = refundedPlans.filter { plan in
                plan.charger?.location == location
            }
            
            // Get all charging session for these plans
            // Flatten child plan chargingSessions (optional arrays) into a single [ChargingSession]
            let relatedChargingSessions: [ChargingSession] = allRelatedPlans.flatMap { $0.chargingSessions ?? [] }
            
            // Filter by month
            let start = month.startOfMonth
            let end = month.endOfMonth
            let relatedSessionsInRange = relatedChargingSessions.filter { session in
                start <= session.endTime && session.endTime <= end
            }
            
            // Get related consumption
            let relatedConsumption = relatedSessionsInRange.reduce(0.0) { partialResult, session in
                partialResult + session.chargedEnergyKWh
            }
            
            // Multiply the session consumption with the specific price of the home consumption
            let totalRefunded = relatedSessionsInRange.reduce(0.0) { partialResult, session in
                partialResult + session.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value * (session.relatedHomeConsumption?.sumOfPriceElementsByConsumption ?? 0.0)
            }
            
            return (Measurement<UnitEnergy>(value: relatedConsumption, unit: UserSettings.shared.energyUnit), totalRefunded)
        } else {
            return (.init(value: 0.0, unit: UserSettings.shared.energyUnit), 0.0)
        }
    }
    
    var grossConsumptionOfMonth: Double {
        let monthKey = UserSettings.shared.groupingDateFormatter.string(from: month)
        return homeConsumptionsForLocation.reduce(0) { partialResult, consumption in
            partialResult + consumption.consumptionForMonth(monthKey: monthKey, includeIfIncludedElsewhere: false)
        }
    }
    
    var netConsumptionOfMonth: Double {
        let monthKey = UserSettings.shared.groupingDateFormatter.string(from: month)
        return homeConsumptionsForLocation.reduce(0) { partialResult, consumption in
            partialResult + consumption.netConsumptionForMonth(monthKey: monthKey)
        }
    }
    
    var chargingCostOfMonth: Double {
        let costOfMonth = costOfMonth
        return costOfMonth.gross - costOfMonth.net
    }
    
    var chargingConsumptionOfMonth: Double {
        grossConsumptionOfMonth - netConsumptionOfMonth
    }
    
    var body: some View {
        Text(month, format: UserSettings.shared.displayDateFormatInSection)
            .font(.title)
            .padding(.top)
            .padding(.horizontal)
        List {
            Text("Location: \(location?.name ?? NSLocalizedString("All locations", comment: ""))")
                .bold()
            
            Section(header: Text("This month's gross data")) {
                HStack {
                    Text("Total Consumption:")
                    Spacer()
                    Text("\(grossConsumptionOfMonth.formatted()) \(UserSettings.shared.energyUnit.symbol)")
                        .bold()
                }
                HStack {
                    Text("Gross Cost:")
                    Spacer()
                    Text(costOfMonth.gross.formatted(.currency(code: UserSettings.shared.currencyIdentifier)))
                        .bold()
                }
                HStack {
                    Text("Specific Gross Cost:")
                    Spacer()
                    let specificCost = grossConsumptionOfMonth > 0 ? costOfMonth.gross / grossConsumptionOfMonth : 0
                    Text("\(specificCost.formatted(.currency(code: UserSettings.shared.currencyIdentifier)))/\(UserSettings.shared.energyUnit.symbol)")
                        .bold()
                }
            }
            
            Section(header: Text("This month's home consumption data")) {
                HStack {
                    Text("Home Consumption:")
                    Spacer()
                    Text("\(netConsumptionOfMonth.formatted()) \(UserSettings.shared.energyUnit.symbol)")
                        .bold()
                }
                HStack {
                    Text("Home Consumption Cost:")
                    Spacer()
                    Text(costOfMonth.net.formatted(.currency(code: UserSettings.shared.currencyIdentifier)))
                        .bold()
                }
                HStack {
                    Text("Specific Home Consumption Cost:")
                    Spacer()
                    let specificCost = netConsumptionOfMonth > 0 ? costOfMonth.net / netConsumptionOfMonth : 0
                    Text("\(specificCost.formatted(.currency(code: UserSettings.shared.currencyIdentifier)))/\(UserSettings.shared.energyUnit.symbol)")
                        .bold()
                }
            }
            
            Section(header: Text("This month's charging data")) {
                HStack {
                    Text("Charging Consumption:")
                    Spacer()
                    Text("\(chargingConsumptionOfMonth.formatted()) \(UserSettings.shared.energyUnit.symbol)")
                        .bold()
                }
                HStack {
                    Text("Charging Cost:")
                    Spacer()
                    Text(chargingCostOfMonth.formatted(.currency(code: UserSettings.shared.currencyIdentifier)))
                        .bold()
                }
                HStack {
                    Text("Specific Charging Cost:")
                    Spacer()
                    let specificCost = chargingCostOfMonth > 0 ? chargingCostOfMonth / chargingConsumptionOfMonth : 0
                    Text("\(specificCost.formatted(.currency(code: UserSettings.shared.currencyIdentifier)))/\(UserSettings.shared.energyUnit.symbol)")
                        .bold()
                }
            }
            
            Section(header: Text("This month's related refunding")) {
                HStack {
                    Text("Energy consumption:")
                    Spacer()
                    Text(refundedCostOfMonth.0.formatted())
                        .bold()
                }
                HStack {
                    Text("Refunded Cost:")
                    Spacer()
                    Text(refundedCostOfMonth.1.formatted(.currency(code: UserSettings.shared.currencyIdentifier)))
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
                            Text(homeConsumption.totalCost(isGross: UserSettings.shared.displayGrossPrices).gross.formatted(.currency(code: UserSettings.shared.currencyIdentifier)))
                        }
                        HStack {
                            Text("Net Cost:")
                            Spacer()
                            Text(homeConsumption.totalCost(isGross: UserSettings.shared.displayGrossPrices).net.formatted(.currency(code: UserSettings.shared.currencyIdentifier)))
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }
    
    init(homeConsumptions: [HomeConsumption], location: Location? = nil) {
        self.homeConsumptions = homeConsumptions
        self.location = location
        
        // Get the location from the first home consumption
        if let location {
            // Fetch all home consumptions for this location
            let locationId = location.id
            self._homeConsumptionsForLocation = Query(filter: #Predicate<HomeConsumption> { $0.associatedLocation?.id == locationId })
        } else {
            // No location, fetch all home consumptions
            self._homeConsumptionsForLocation = Query()
        }
    }
}
