//
//  Location.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 22/11/2025.
//

import Foundation
import SwiftData

@Model
final class Charger {
    var id: UUID
    var name: String
    var location: Location?
    var isArchived: Bool = false
    
    var description: String {
        var description = name
        if let location = location {
            description += " (\(location.name))"
        }
        return description
    }
    
    init(id: UUID = UUID(), name: String, location: Location? = nil) {
        self.id = id
        self.name = name
        self.location = location
    }
}
