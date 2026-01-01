//
//  ChargingViewSummary.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 31/12/2025.
//

import SwiftUI

struct ChargingViewSummary: View {
    let chargingData: ChargingData
    
    var body: some View {
        HStack {
            Text("Charged energy")
            Spacer()
            Text(chargingData.totalChargedEnergy.formatted())
        }
        
        HStack {
            Text("Direct charging cost")
            Spacer()
            Text(chargingData.totalChargingCost.formatted())
        }
        
        if let totalConsumption = chargingData.consumptionData?.totalConsumption {
            HStack {
                Text("Average consumption")
                Spacer()
                Text(totalConsumption.consumptionDescription)
            }
        } else {
            HStack {
                Text("Average consumption")
                Spacer()
                Text("No data")
                    .italic()
            }
        }
    }
}
