//
//  HomeViewSummary.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 25/01/2026.
//

import SwiftUI

struct HomeViewSummary: View {
    let location: Location
    let timeBox: TimeBox

    // Observe UserSettings so changes cause view refresh
    @ObservedObject private var settings = UserSettings.shared
    
    var body: some View {
        Text("TODO") // TODO: Refactor
    }
}
