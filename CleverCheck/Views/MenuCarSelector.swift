//
//  MenuCarSelector.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 01/01/2026.
//

import SwiftUI

struct MenuCarSelector: View {
    @Binding var selectedCar: Car?
    var allCars: [Car]
    
    var body: some View {
        Button(action: {
            selectedCar = nil
            UserSettings.shared.selectedCarId = nil
        }) {
            Text("All vehicles")
        }
        ForEach(allCars, id: \.self) { car in
            Button(action: {
                selectedCar = car
                UserSettings.shared.selectedCarId = car.id.uuidString
            }) {
                Text(car.description)
            }
        }
    }
}
