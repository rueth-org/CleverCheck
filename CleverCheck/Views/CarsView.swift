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
    @Query(sort: [SortDescriptor(\Car.make), SortDescriptor(\Car.model)]) private var cars: [Car]
    @Query private var chargingCostPlans: [ChargingCostPlan]
    
    var body: some View {
        VStack {
            if cars.isEmpty {
                Spacer()
                Image(systemName: "bolt.car")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No cars found.")
                Spacer()
            } else {
                List {
                    ForEach(cars, id: \.self) { car in
                        NavigationLink(value: NavigationDestination.EditCar(car: car)) {
                            Text(car.description)
                        }
                        .swipeActions {
                            if canDelete(car) {
                                Button(role: .destructive) {
                                    deleteCar(for: car)
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
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Cars")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: newCar) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private func newCar() {
        navigationPath.append(NavigationDestination.NewCar)
    }
    
    private func deleteCar(for car: Car) {
        // Check if car is selected in app storage, unselect if yes
        if UserSettings.shared.selectedCarId == car.id.uuidString {
            UserSettings.shared.selectedCarId = nil
        }
        withAnimation {
            modelContext.delete(car)
        }
    }
    
    private func canDelete(_ car: Car) -> Bool {
        return !chargingCostPlans.contains { $0.car == car }
    }
}
