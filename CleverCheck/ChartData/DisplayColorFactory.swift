//
//  ChartHelpers.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 14/02/2026.
//

import Foundation
import SwiftUI
import SwiftData

protocol GraphItem: Hashable & Comparable {
    var legendLabel: String { get }
    var displayColor: DisplayColor { get }
}

enum DisplayColor: String, Hashable, CaseIterable {
    case blue, green, orange, pink, purple, yellow, gray, red, teal, indigo
    
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
