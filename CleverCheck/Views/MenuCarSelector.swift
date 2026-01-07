//
//  MenuCarSelector.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 01/01/2026.
//

import SwiftUI

struct MenuCarSelector: View {
    @Binding var selectedCar: Car?
    @Binding var selectedTimePeriod: (Date, Date)?
    var allCars: [Car]
    
    var body: some View {
        Button(action: {
            selectedCar = nil
            selectedTimePeriod = nil
            UserSettings.shared.selectedCarId = nil
        }) {
            Text("All vehicles")
        }
        ForEach(allCars, id: \.id) { car in
            Button(action: {
                selectedTimePeriod = nil
                selectedCar = car
                UserSettings.shared.selectedCarId = car.id.uuidString
            }) {
                Text(car.description)
            }
        }
    }
}
