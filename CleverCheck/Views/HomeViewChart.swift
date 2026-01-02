//
//  HomeViewChart.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 02/01/2026.
//

import SwiftUI
import Charts

struct HomeViewChart: View {
    var homeData: HomeData
    
    // Optional callback invoked when a bar is tapped; receives the x-axis key (month) as String
    var onBarTap: ((String) -> Void)? = nil
    
    var body: some View {
        Chart {
            ForEach(homeData.data.sorted(by: { $0.key < $1.key }), id: \.key) { pair in
                let dataSet = pair.value
                BarMark(
                    x: .value("Month", pair.key),
                    y: .value("Net consumption", dataSet.homeConsumptionNet.value)
                )
                .annotation(position: .top) {
                    Text(UserSettings.shared.format(dataSet.homeConsumptionNet.value, withSignificantDigits: 3))
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
