//
//  MenuHomeSelector.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 02/01/2026.
//

import SwiftUI

struct MenuHomeSelector: View {
    @Binding var selectedHome: Location?
    @Binding var selectedTimePeriod: (Date, Date)?
    var allHomes: [Location]
    
    var body: some View {
        Button(action: {
            selectedTimePeriod = nil
            selectedHome = nil
            UserSettings.shared.selectedLocationId = nil
        }) {
            Text("All homes")
        }
        ForEach(allHomes, id: \.id) { home in
            Button(action: {
                selectedTimePeriod = nil
                selectedHome = home
                UserSettings.shared.selectedLocationId = home.id.uuidString
            }) {
                Text(home.name)
            }
        }
    }
}
