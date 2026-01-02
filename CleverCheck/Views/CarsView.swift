//
//  CarsView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 25/11/2025.
//

import SwiftUI
import SwiftData

struct CarsView: View {
    enum NavigationDestination: Hashable {
        case NewCar
        case EditCar(car: Car)
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    
    @Query(filter: #Predicate<ChargingCostPlan> { plan in
        plan.isArchived == false
    }) private var chargingCostPlans: [ChargingCostPlan]
    
    @State private var isShowingArchived: Bool = false
    
    var predicate: Predicate<Car> {
        var predicate: Predicate<Car>
        if !isShowingArchived {
            predicate = #Predicate<Car> { car in
                car.isArchived == false
            }
        } else {
            predicate = .true
        }
        return predicate
    }
    
    var body: some View {
        List {
            DynamicList(
                predicate: predicate,
                sorting: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)],
                emptyStateMessage: "No cars found.",
                emptyStateSystemImage: "bolt.car"
            ) { car in
                NavigationLink(value: NavigationDestination.EditCar(car: car)) {
                    Text(car.description)
                }
                .swipeActions {
                    if canDelete(car) {
                        Button(role: .destructive) {
                            deleteCar(car)
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
                Text("Cars")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: {
                    withAnimation {
                        isShowingArchived.toggle()
                    }
                }) {
                    Image(systemName: isShowingArchived ? "archivebox.circle.fill" : "archivebox.circle")
                        .foregroundStyle(isShowingArchived ? .blue : .primary)
                }
                Button(action: newCar) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private func newCar() {
        navigationPath.append(NavigationDestination.NewCar)
    }
    
    private func deleteCar(_ car: Car) {
        // Check if car is selected in app storage, unselect if yes
        if UserSettings.shared.selectedCarId == car.id.uuidString {
            UserSettings.shared.selectedCarId = nil
        }
        withAnimation {
            modelContext.delete(car)
        }
        try? modelContext.save()
    }
    
    private func canDelete(_ car: Car) -> Bool {
        return !chargingCostPlans.contains { $0.car == car }
    }
}
