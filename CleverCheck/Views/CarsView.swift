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
    @State private var selectedCar: Car? = nil
    
    var body: some View {
        List {
            ForEach(cars, id: \.self) { car in
                NavigationLink(value: NavigationDestination.EditCar(car: car)) {
                    Text("\(car.make) \(car.model)")
                }
            }
            .onDelete(perform: deleteCar)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Cars")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button(action: newCar) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private func newCar() {
        navigationPath.append(NavigationDestination.NewCar)
    }
    
    private func deleteCar(at offsets: IndexSet) {
        // TODO check if can be deleted
        for offset in offsets {
            // Find car in our query
            let car = cars[offset]

            // Delete it from the context
            withAnimation {
                modelContext.delete(car)
            }
        }
    }
}
