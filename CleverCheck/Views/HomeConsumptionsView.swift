//
//  ContentView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import SwiftUI
import SwiftData

struct HomeConsumptionsView: View {
    enum NavigationDestination: Hashable {
        case NewConsumption
        case EditConsumption(homeConsumption: HomeConsumption)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    
    @Query(sort: [SortDescriptor(\HomeConsumption.validUntil), SortDescriptor(\HomeConsumption.name)]) private var homeConsumptions: [HomeConsumption]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
    private var groupedByMonths: [Date: [HomeConsumption]] {
        Dictionary(grouping: homeConsumptions) { consumption in
            let components = Calendar.current.dateComponents([.year, .month], from: consumption.validUntil)
            return Calendar.current.date(from: components)!
        }
    }
    
    var body: some View {
        VStack {
            if homeConsumptions.isEmpty {
                Spacer()
                Image(systemName: "house.circle")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No home consumptions found.")
                Spacer()
            } else {
                List {
                    ForEach(groupedByMonths.keys.sorted(), id: \.self) { month in
                        Section(header: Text(month, format: Date.FormatStyle().year().month(.wide))) {
                            ForEach(groupedByMonths[month]!, id: \.self) { homeConsumption in
                                NavigationLink(value: NavigationDestination.EditConsumption(homeConsumption: homeConsumption)) {
                                    Text(homeConsumption.name)
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Home Consumptions")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button(action: addHomeConsumption) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert(
            activeAlert?.title() ?? "Notice",
            isPresented: $showingAlert,
            presenting: activeAlert
        ) { activeAlert in
            activeAlert.button()
        } message: { activeAlert in
            activeAlert.message()
        }
    }
    
    private func addHomeConsumption() {
        navigationPath.append(NavigationDestination.NewConsumption)
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
        }
    }
    
    private func duplicate(_ homeConsumption: HomeConsumption) {
        let newConsumption = HomeConsumption(
            name: homeConsumption.name + " Copy",
            validFrom: homeConsumption.validFrom,
            validUntil: homeConsumption.validUntil,
            consumption: homeConsumption.consumption,
            associatedChargingLocation: homeConsumption.associatedChargingLocation
        )
        
        for priceElement in homeConsumption.priceElements {
            let newPriceElement = PriceElement(
                label: priceElement.label,
                amount: priceElement.amount,
                isGross: priceElement.isGross,
                type: priceElement.type,
                vatRate: priceElement.vatRate
            )
            newConsumption.priceElements.append(newPriceElement)
        }
        
        modelContext.insert(newConsumption)
    }
}
