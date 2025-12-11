//
//  ChargingView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/12/2025.
//

import SwiftUI

struct ChargingView: View {
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        Text("Charging")
            .font(.headline)
            .padding()
        Spacer()
        VStack {
            Button(action: {
                navigationPath.append(ContentView.NavigationDestination.ChargingSessions)
            }) {
                Text("Charging Sessions")
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .font(.system(size: 18))
                    .padding()
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
            .background(Color.blue)
            .cornerRadius(25)
        }
        .padding()
        Spacer()
    }
}
