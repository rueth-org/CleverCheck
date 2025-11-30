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
    
    @Query(sort: \HomeConsumption.name) private var homeConsumptions: [HomeConsumption]
    
    @State private var showingAlert: Bool = false
    @State private var activeAlert: SimpleAlertType?
    
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
                    ForEach(homeConsumptions, id: \.self) { homeConsumption in
                        NavigationLink(value: NavigationDestination.EditConsumption(homeConsumption: homeConsumption)) {
                            Text(homeConsumption.name)
                        }
                    }
                    .onDelete(perform: deleteHomeConsumption)
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
}
