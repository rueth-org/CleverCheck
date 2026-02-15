//
//  ChartHelpers.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 14/02/2026.
//

import Foundation
import SwiftUI

protocol GraphItem: Hashable & Comparable {
    var legendLabel: String { get }
    var displayColor: DisplayColor { get }
}

enum DisplayColor: String, Hashable, CaseIterable {
    case blue, green, orange, pink, purple, yellow, gray, red, teal, indigo
    
    init?(rawValue: String) {
        switch rawValue {
        case "blue": self = .blue
        case "green": self = .green
        case "orange": self = .orange
        case "pink": self = .pink
        case "purple": self = .purple
        case "yellow": self = .yellow
        case "gray": self = .gray
        case "red": self = .red
        case "teal": self = .teal
        case "indigo": self = .indigo
        default: return nil
        }
    }
    
    init?(uiColor: UIColor) {
        switch uiColor {
        case .systemBlue: self = .blue
        case .systemGreen: self = .green
        case .systemOrange: self = .orange
        case .systemPink: self = .pink
        case .systemPurple: self = .purple
        case .systemYellow: self = .yellow
        case .systemGray: self = .gray
        case .systemRed: self = .red
        case .systemTeal: self = .teal
        case .systemIndigo: self = .indigo
        default: return nil
        }
    }
    
    func toColor() -> Color {
        switch self {
        case .blue: return Color(.systemBlue)
        case .green: return Color(.systemGreen)
        case .orange: return Color(.systemOrange)
        case .pink: return Color(.systemPink)
        case .purple: return Color(.systemPurple)
        case .yellow: return Color(.systemYellow)
        case .gray: return Color(.systemGray)
        case .red: return Color(.systemRed)
        case .teal: return Color(.systemTeal)
        case .indigo: return Color(.systemIndigo)
        }
    }
    
    func toUIColor() -> UIColor {
        UIColor(self.toColor())
    }
}

// Source - https://stackoverflow.com/a/65075376
// Posted by user3151675, modified by community. See post 'Timeline' for change history
// Retrieved 2026-02-15, License - CC BY-SA 4.0

struct DisplayColorPicker: View {
    var colors: [[DisplayColor]] = [
        [
            .blue,
            .green,
            .orange,
            .pink,
            .purple
        ],
        [
            .yellow,
            .gray,
            .red,
            .teal,
            .indigo
        ]
    ]

    @Binding var selectedColor: DisplayColor

    var body: some View {
        VStack {
            colorPalette

            HStack(alignment: .center) {
                Text("Selected color:")

                Color(selectedColor.toColor())
                    .frame(width: 60, height: 60)
            }
        }
    }

    var colorPalette: some View {
        VStack(spacing: 0) {
            ForEach(colors, id: \.self) { colorRowColors in
                getColorRow(colors: colorRowColors)
            }
        }
    }

    func getColorRow(colors: [DisplayColor]) -> some View {
        HStack(spacing: 0) {
            ForEach(colors, id: \.self) { color in
                Button {
                    selectedColor = color
                } label: {
                    Color(color.toColor())
                        .border(Color.gray, width: color == selectedColor ? 2 : 0)
                }
            }
        }
    }
}


final class DisplayColorFactory {
    static let shared = DisplayColorFactory()
    
    var categoryColors = [String: [String: DisplayColor]]()
    
    private init() { }
    
    func add(legendEntry: String, to factory: String) -> DisplayColor {
        // Get or create factory
        if categoryColors[factory] == nil {
            categoryColors[factory] = [:]
        }
        if let color = categoryColors[factory]?[legendEntry] {
            return color
        } else {
            let newColor = categoryColorScale(for: factory)
            categoryColors[factory]?[legendEntry] = newColor
            return newColor
        }
    }
    
    private func categoryColorScale(for factory: String) -> DisplayColor {
        // Get the number of previous entries
        let previousEntries = categoryColors[factory]?.count ?? 0
        
        // Return the next entry of palette, wrapping around indefinitely if reaching the end
        let allColors = DisplayColor.allCases
        let colorIndex = previousEntries % allColors.count
        return allColors[colorIndex]
    }
}
