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
        case NewPrice
        case EditPrice(seasonalPrice: SeasonalPrice)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
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
                HStack {
                    Image(systemName: seasonalPrice == selectedSeasonalPrice ? "checkmark.circle.fill" : "circle")
                            .imageScale(.large)
                            .foregroundStyle(seasonalPrice == selectedSeasonalPrice ? .green : .gray)
                    VStack(alignment: .leading) {
                        Text("\(seasonalPrice.name)")
                        Text("\(seasonalPrice.startDate, format: UserSettings.shared.displayDateFormat) - \(seasonalPrice.endDate, format: UserSettings.shared.displayDateFormat)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .onTapGesture {
                    if seasonalPrice == selectedSeasonalPrice {
                        // Unselect seasonal price
                        selectedSeasonalPrice = nil
                    } else {
                        // Select seasonal price
                        selectedSeasonalPrice = seasonalPrice
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        navigationPath.append(NavigationDestination.EditPrice(seasonalPrice: seasonalPrice))
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }.tint(.blue)
                }
                .swipeActions(edge: .trailing) {
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
        navigationPath.append(NavigationDestination.NewPrice)
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
