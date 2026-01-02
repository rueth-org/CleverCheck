//
//  DynamicList.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 02/12/2025.
//

import SwiftUI
import SwiftData

struct DynamicList<T: PersistentModel, Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var fetchedData: [T]
    let groupBy: ((T) -> String)?
    let content: (T) -> Content
    let emptyStateMessage: LocalizedStringKey
    let emptyStateSystemImage: String?
    
    private var grouping: [String: [T]]? {
        guard let groupBy else { return nil }
        return Dictionary(grouping: fetchedData, by: groupBy)
    }
    
    var body: some View {
        // Empty state view
        if fetchedData.isEmpty {
            HStack {
                Spacer()
                if let emptyStateSystemImage {
                    Image(systemName: emptyStateSystemImage)
                }
                Text(emptyStateMessage)
                    .foregroundColor(.gray)
                Spacer()
            }
        } else {
            if let groupedItems = grouping {
                ForEach(groupedItems.keys.sorted(), id: \.self) { groupingKey in
                    Section(header: Text(groupingKey)) {
                        ForEach(groupedItems[groupingKey] ?? [], id: \.id) { item in
                            self.content(item)
                        }
                    }
                }
            } else {
                ForEach(fetchedData, id: \.id) { item in
                    self.content(item)
                }
            }
        }
    }
    
    init(
        predicate: Predicate<T>?,
        sorting: [SortDescriptor<T>]? = nil,
        groupBy: ((T) -> String)? = nil,
        emptyStateMessage: LocalizedStringKey = "No data",
        emptyStateSystemImage: String? = nil,
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.groupBy = groupBy
        
        if let sorting {
            _fetchedData = Query(filter: predicate, sort: sorting)
        } else {
            _fetchedData = Query(filter: predicate)
        }
        
        // Assign the content closure
        self.content = content
        
        // Assign the empty state closure
        self.emptyStateMessage = emptyStateMessage
        self.emptyStateSystemImage = emptyStateSystemImage
    }
}

