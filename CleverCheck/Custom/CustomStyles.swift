//
//  ButtonStyles.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 24/02/2026.
//

import Foundation
import SwiftUI

//
// Button styles
//

struct BlueButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.blue)
            .cornerRadius(25)
            .padding()
    }
}

//
// Text styles
//

protocol TextStyle: ViewModifier {}

extension Text {
    func textStyle<T: TextStyle>(_ style: T) -> some View {
        modifier(style)
    }
}

struct BlueButtonText: TextStyle {
    func body(content: Content) -> some View {
        content
            .frame(minWidth: 0, maxWidth: .infinity)
            .font(.system(size: 18))
            .padding()
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white, lineWidth: 2)
            )
    }
}
