//
//  DynamicList.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 02/12/2025.
//

import SwiftUI
import SwiftData

struct DynamicList<T: PersistentModel, Content: View>: View {
    @Query private var fetchedData: [T]
    let content: (T) -> Content
    let emptyStateMessage: String
    let emptyStateSystemImage: String?
    
    var body: some View {
        List(fetchedData, id: \.self) { item in
            self.content(item)
        }
        
        // Empty state view
        if fetchedData.isEmpty {
            Text(emptyStateMessage)
                .foregroundColor(.gray)
                .padding()
            if let emptyStateSystemImage {
                Image(systemName: emptyStateSystemImage)
            }
        }
        
    }
    
    init(
        predicate: Predicate<T>?,
        sorting: [SortDescriptor<T>]?,
        sortAscending: Bool?,
        emptyStateMessage: String = "No items found",
        emptySSateSystemImage: String? = nil,
        @ViewBuilder content: @escaping (T) -> Content
    ) throws {
        if let sorting {
            _fetchedData = Query(filter: predicate, sort: sorting)
        } else {
            _fetchedData = Query(filter: predicate)
        }
        
        // Assign the content closure
        self.content = content
        
        // Assign the empty state closure
        self.emptyStateMessage = emptyStateMessage
        self.emptyStateSystemImage = emptySSateSystemImage
    }
}
