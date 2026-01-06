//
//  HomeConsumptionsList.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 12/12/2025.
//

import SwiftUI
import SwiftData

struct HomeConsumptionsList: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @Binding var preselectedConsumptions: [HomeConsumption]?
    @Query private var homeConsumptions: [HomeConsumption]
    
    private var groupedByMonths: [Date: [HomeConsumption]] {
        Dictionary(grouping: preselectedConsumptions ?? homeConsumptions) { consumption in
            let components = Calendar.current.dateComponents([.year, .month], from: consumption.validUntil)
            return Calendar.current.date(from: components)!
        }
    }
    
    var body: some View {
        if groupedByMonths.isEmpty {
            Spacer()
            Image(systemName: "house.circle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No home consumptions found.")
            Spacer()
        } else {
            List {
                ForEach(groupedByMonths.keys.sorted(by: { $0 > $1 }), id: \.self) { month in
                    Section(header: Text(month, format: UserSettings.shared.displayDateFormatInSection)) {
                        // The total cost for the month
                        NavigationLink(value: groupedByMonths[month]!) {
                            HStack {
                                Text("Total:")
                                Spacer()
                                Text(totalCost(for: month), format: .currency(code: UserSettings.shared.currencyIdentifier))
                            }
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        }
                        
                        // The list of home consumptions ending this month
                        ForEach(groupedByMonths[month]!, id: \.self) { homeConsumption in
                            NavigationLink(value: HomeConsumptionsView.NavigationDestination.EditConsumption(homeConsumption: homeConsumption)) {
                                VStack(alignment: .leading) {
                                    Text(homeConsumption.name)
                                    HStack {
                                        //Display dateoFrm - dateUntil  inshort format
                                        Text("\(homeConsumption.validFrom, format: UserSettings.shared.displayDateFormat) - \(homeConsumption.validUntil, format: UserSettings.shared.displayDateFormat)")
                                        Spacer()
                                        Text(homeConsumption.totalCost(isGross: UserSettings.shared.displayGrossPrices), format: .currency(code: UserSettings.shared.currencyIdentifier))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    duplicate(homeConsumption)
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                .tint(.yellow)
                            }
                        }
                        .onDelete { offsets in
                            // Map offsets to the correct indices in homeConsumptions
                            let allConsumptionsInMonth = groupedByMonths[month]!
                            let indicesToDelete = offsets.map { index in
                                homeConsumptions.firstIndex(of: allConsumptionsInMonth[index])!
                            }
                            deleteHomeConsumption(at: IndexSet(indicesToDelete))
                        }
                    }
                }
            }
        }
    }
    
    init(
        navigationPath: Binding<NavigationPath>,
        preselectedConsumptions: Binding<[HomeConsumption]?>,
        associatedLocation: Location?
    ) {
        self._navigationPath = navigationPath
        self._preselectedConsumptions = preselectedConsumptions
        
        var predicate: Predicate<HomeConsumption>
        if let id = associatedLocation?.persistentModelID {
            predicate = #Predicate<HomeConsumption> { homeConsumption in
                homeConsumption.associatedLocation?.persistentModelID == id
            }
        } else {
            predicate = .true
        }
        
        _homeConsumptions = Query(
            filter: predicate,
            sort: [SortDescriptor(\HomeConsumption.validUntil), SortDescriptor(\HomeConsumption.name)]
        )
    }
    
    private func duplicate(_ homeConsumption: HomeConsumption) {
        let newConsumption = HomeConsumption(
            name: homeConsumption.name + NSLocalizedString(" Copy", comment: ""),
            validFrom: homeConsumption.validFrom,
            validUntil: homeConsumption.validUntil,
            consumption: homeConsumption.consumption,
            consumptionIncludedElsewhere: homeConsumption.consumptionIncludedElsewhere,
            associatedLocation: homeConsumption.associatedLocation
        )
        
        if let priceElements = homeConsumption.priceElements {
            newConsumption.priceElements = [PriceElement]()
            for priceElement in priceElements {
                let newPriceElement = PriceElement(
                    label: priceElement.label,
                    amount: priceElement.amount,
                    isGross: priceElement.isGross,
                    type: priceElement.type,
                    vatRate: priceElement.vatRate
                )
                newConsumption.priceElements!.append(newPriceElement)
            }
        }
        
        modelContext.insert(newConsumption)
    }
    
    private func deleteHomeConsumption(at offsets: IndexSet) {
        // TODO check if can be deleted
        for offset in offsets {
            // Find home consumption in our query
            let homeConsumption = homeConsumptions[offset]

            // Delete it from the context
            withAnimation {
                modelContext.delete(homeConsumption)
            }
            try? modelContext.save()
        }
    }
    
    private func totalCost(for month: Date) -> Double {
        let monthString = UserSettings.shared.groupingDateFormatter.string(from: month)
        var total: Double = 0.0
        for homeConsumption in homeConsumptions {
            total += homeConsumption.totalCostPerMonth(isGross: UserSettings.shared.displayGrossPrices)[monthString] ?? 0.0
        }
        return total
    }
}
