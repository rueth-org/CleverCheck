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
    @Query private var homeConsumptions: [HomeConsumption]
    
    private var groupedByMonths: [Date: [HomeConsumption]] {
        Dictionary(grouping: homeConsumptions) { consumption in
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
                        HStack {
                            Text("Total:")
                            Spacer()
                            Text(cost(for: month).formatted())
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
                                        Text(homeConsumption.totalCost(
                                            includingVAT: UserSettings.shared.displayGrossPrices,
                                            useRelatedConsumptions: UserSettings.shared.useRelatedConsumptions
                                        ).formatted())
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(homeConsumption)
                                } label: {
                                    Label("Delete", systemImage: "trash")
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
                    }
                }
            }
        }
    }
    
    init(
        navigationPath: Binding<NavigationPath>,
        timeBox: TimeBox,
        associatedLocation: Location?
    ) {
        self._navigationPath = navigationPath
        
        var predicate: Predicate<HomeConsumption>
        if let id = associatedLocation?.persistentModelID {
            if let timePeriod = timeBox.timePeriod {
                let start = timePeriod.start
                let end = timePeriod.end
                predicate = #Predicate<HomeConsumption> { homeConsumption in
                    homeConsumption.associatedLocation?.persistentModelID == id && start <= homeConsumption.validUntil && homeConsumption.validUntil <= end
                }
            } else {
                predicate = #Predicate<HomeConsumption> { homeConsumption in
                    homeConsumption.associatedLocation?.persistentModelID == id
                }
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
                    inclVAT: priceElement.isGross,
                    type: priceElement.type,
                    vatRate: priceElement.vatRate
                )
                newConsumption.priceElements!.append(newPriceElement)
            }
        }
        
        modelContext.insert(newConsumption)
    }
    
    private func delete(_ homeConsumption: HomeConsumption) {
        // Delete it from the context
        withAnimation {
            modelContext.delete(homeConsumption)
        }
        try? modelContext.save()
    }
    
    private func cost(for month: Date) -> Cost {
        let monthString = UserSettings.shared.groupingDateFormatter.string(from: month)
        var total: Cost = .init(amount: 0.0)
        for homeConsumption in homeConsumptions {
            total += homeConsumption.totalCostPerMonth(
                includingVAT: UserSettings.shared.displayGrossPrices,
                useRelatedConsumptions: UserSettings.shared.useRelatedConsumptions
            )[monthString] ?? .init(amount: 0.0)
        }
        return total
    }
}
