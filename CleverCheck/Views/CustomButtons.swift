//
//  CustomButtons.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 23/11/2025.
//

import SwiftUI

//
// Button Styles
//

struct ActionButton: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    static let safeButtonSpace: CGFloat = 80
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .foregroundColor(.blue)
            .background(.yellow)
            .cornerRadius(20)
            .saturation(isEnabled ? 1 : 0)
    }
}

struct CancelButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .foregroundColor(.black)
            .background(.gray)
            .cornerRadius(20)
    }
}
