//
//  SeasonalPriceGroup.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 03/11/2026.
//

import SwiftData
import Foundation

/// Represents a seasonal price group.
@Model
final class SeasonalPriceGroup: Identifiable, Equatable, Comparable {
    var id: UUID = UUID()
    var name: String = ""
    var countryCode: String = ""
    
    @Relationship(deleteRule: .nullify, inverse: \SeasonalPrice.group)
    var seasonalPrices: [SeasonalPrice]?
    
    init(name: String, countryCode: String) {
        self.name = name
        self.countryCode = countryCode
    }
    
    static func < (lhs: SeasonalPriceGroup, rhs: SeasonalPriceGroup) -> Bool {
        return lhs.name < rhs.name
    }
    
    static func getOrCreateSeasonalPriceGroup(name: String, countryCode: String, in context: ModelContext) -> SeasonalPriceGroup {
        let fetchDescriptor = FetchDescriptor<SeasonalPriceGroup>(predicate: #Predicate { $0.name == name && $0.countryCode == countryCode })
        if let existingGroup = try? context.fetch(fetchDescriptor).first {
            return existingGroup
        } else {
            let newGroup = SeasonalPriceGroup(name: name, countryCode: countryCode)
            context.insert(newGroup)
            try? context.save()
            return newGroup
        }
    }
}
