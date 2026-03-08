//
//  Template.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 19/02/2026.
//

import Foundation
import SwiftData

@Model
final class ChargingSessionTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var chargingSession: ChargingSession?
    
    init(name: String, chargingSession: ChargingSession? = nil) {
        self.name = name
        self.chargingSession = chargingSession
    }
}
