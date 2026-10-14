//
//  SeasonalPricesView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 13/10/2026.
//

import SwiftUI
import SwiftData

struct SeasonalPricesView: View {
    enum NavigationDestination: Hashable {
        case NewPrice(parentPriceElement: PriceElement)
        case EditPrice(seasonalPrice: SeasonalPrice, parentPriceElement: PriceElement)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    let parentPriceElement: PriceElement
    @Binding var selectedSeasonalPrice: SeasonalPrice?
    
    var predicate: Predicate<SeasonalPrice> {
        .true
    }
    
    var body: some View {
        List {
            DynamicList(
                predicate: predicate,
                sorting: [SortDescriptor(\SeasonalPrice.startDate)],
                emptyStateMessage: "No seasonal prices found.",
                emptyStateSystemImage: "banknote"
            ) { seasonalPrice in
                NavigationLink(value: NavigationDestination.EditPrice(seasonalPrice: seasonalPrice, parentPriceElement: parentPriceElement)) {
                    HStack {
                        Button(action: {
                            if seasonalPrice == selectedSeasonalPrice {
                                // Unselect seasonal price
                                selectedSeasonalPrice = nil
                            } else {
                                // Select seasonal price
                                selectedSeasonalPrice = seasonalPrice
                            }
                        }) {
                            Image(systemName: seasonalPrice == selectedSeasonalPrice ? "checkmark.circle.fill" : "circle")
                                .imageScale(.large)
                                .foregroundStyle(seasonalPrice == selectedSeasonalPrice ? .green : .gray)
                        }.buttonStyle(.plain)
                        Text("\(seasonalPrice.startDate.formatted())-\(seasonalPrice.endDate.formatted())")
                    }
                }
                .swipeActions {
                    if canDelete(seasonalPrice) {
                        Button(role: .destructive) {
                            deleteSeasonalPrice(seasonalPrice)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            // no action
                        } label: {
                            Label("Cannot delete", systemImage: "trash")
                        }
                        .tint(.secondary)
                        .disabled(true)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Seasonal Prices")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: newSeasonalPrice) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private func newSeasonalPrice() {
        navigationPath.append(NavigationDestination.NewPrice(parentPriceElement: parentPriceElement))
    }
    
    private func deleteSeasonalPrice(_ seasonalPrice: SeasonalPrice) {
        withAnimation {
            modelContext.delete(seasonalPrice)
        }
        try? modelContext.save()
    }
    
    private func canDelete(_ seasonalPrice: SeasonalPrice) -> Bool {
        true
    }
}
