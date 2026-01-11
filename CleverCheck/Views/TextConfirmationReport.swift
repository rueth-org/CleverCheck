//
//  TextConfirmationView.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/01/2026.
//

import SwiftUI

struct TextConfirmationReport: View {
    var report: [String]
    
    var reportText: String {
        report.joined(separator: "\n")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                TextEditor(text: .constant(reportText))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
    }
}
