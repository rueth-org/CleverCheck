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
            ForEach(chargingData.chargingSessions, id: \.self) { session in
                BarMark(
                    x: .value("End Time", DateFormatter.chartDisplayDateMonthly.string(from: session.endTime)),
                    y: .value("Charged Energy", session.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value)
                )
                .annotation(position: .top) {
                    Text(session.chargedEnergy.converted(to: UserSettings.shared.energyUnit).value.formatted(.number.precision(.fractionLength(1))))
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
         formatter.dateFormat = "d."
         return formatter
    }()
}
