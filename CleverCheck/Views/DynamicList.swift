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
    let content: (T) -> Content
    let canDelete: (T) -> Bool
    let emptyStateMessage: String
    let emptyStateSystemImage: String?
    
    @Binding var showingAlert: Bool
    @Binding var activeAlert: SimpleAlertType?
    
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
            ForEach(fetchedData, id: \.self) { item in
                self.content(item)
            }
            .onDelete(perform: delete)
        }
    }
    
    init(
        predicate: Predicate<T>?,
        sorting: [SortDescriptor<T>]?,
        emptyStateMessage: String = "No items found",
        emptyStateSystemImage: String? = nil,
        activeAlert: Binding<SimpleAlertType?>,
        showingAlert: Binding<Bool>,
        canDelete: @escaping (T) -> Bool,
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.canDelete = canDelete
        self._activeAlert = activeAlert
        self._showingAlert = showingAlert
        
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
    
    private func delete(at offsets: IndexSet) {
        for offset in offsets {
            // Find item in our query
            let item = fetchedData[offset]

            // Delete it from the context if possible
            if canDelete(item) {
                withAnimation {
                    modelContext.delete(item)
                }
            } else {
                activeAlert = .warning(
                    message: "Cannot delete this item."
                )
                showingAlert = true
            }
        }
    }
}
