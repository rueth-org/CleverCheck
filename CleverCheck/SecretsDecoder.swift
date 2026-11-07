//
//  SecretsDecoder.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 06/11/2026.
//

import Foundation

enum Secrets {
    static var energyDataApiKey: String {
        guard let apiKey = Bundle.main.infoDictionary?["ENERGY_DATA_API_KEY"] as? String else {
            fatalError("Missing ENERGY_DATA_API_KEY in Secrets.xcconfig")
        }
        return apiKey
    }
}
