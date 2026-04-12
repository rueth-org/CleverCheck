//
//  ChartFiltersSheet.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 12/04/2026.
//

import SwiftUI

/// Reusable view that displays an array of Toggles.
/// Generic over the Toggle label type so callers can pass `Toggle<Text>`.
struct ChartFiltersSheet<Label: View>: View {
    let toggles: [Toggle<Label>]

    // Compute a detent height based on the number of toggles, spacing and padding.
    // We estimate a per-row height and include spacing + vertical padding and a small
    // extra for the drag indicator. Clamp to a sensible min/max so the sheet
    // doesn't become too small or overly large.
    private var detentHeight: CGFloat {
        let perRowHeight: CGFloat = 44      // estimated height for a Toggle row
        let spacing: CGFloat = 12          // matches VStack spacing
        let verticalPadding: CGFloat = 16 * 2 // default .padding() adds ~16 on top and bottom
        let dragIndicatorExtra: CGFloat = 20
        let minHeight: CGFloat = 120
        let maxHeight: CGFloat = 800

        let rows = CGFloat(max(0, toggles.count))
        // Total spacing between rows is (n-1) * spacing when n > 0
        let totalSpacing = rows > 0 ? (rows - 1) * spacing : 0

        let calculated = rows * perRowHeight + totalSpacing + verticalPadding + dragIndicatorExtra
        return min(max(calculated, minHeight), maxHeight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<toggles.count, id: \.self) { idx in
                toggles[idx]
            }
        }
        .padding()
        .presentationDetents([.height(detentHeight), .medium])
        .presentationDragIndicator(.visible)
    }
}
