//
//  HomeData.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 11/12/2025.
//

import Foundation

struct HomeData: Identifiable {
    var id = UUID()
    var totalCost: Cost
    var specificCost: Cost
    var totalConsumption: Measurement<UnitEnergy>
}
