//
//  ChargingViewChart.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 21/12/2025.
//

import SwiftUI
import Charts

struct ChargingViewChart: View {
    var chargingData: ChargingData
    
    var body: some View {
        Chart {
            ForEach(chargingData.chargedEnergy.sorted(by: { $0.key < $1.key }), id: \.key) { pair in
                BarMark(
                    x: .value("End Time", pair.key),
                    y: .value("Charged Energy", pair.value)
                )
                .annotation(position: .top) {
                    Text(pair.value.formatted(.number.precision(.fractionLength(1))))
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(5)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(5)
                }
            }
        }
    }
}

extension DateFormatter {
    static let chartDisplayDateMonthly: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "dd"
         return formatter
    }()
    
    static let chartDisplayDateYearly: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "MM"
         return formatter
    }()
}
