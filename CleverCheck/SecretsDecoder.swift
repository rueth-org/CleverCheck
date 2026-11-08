//
//  SecretsDecoder.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 06/11/2026.
//

import Foundation

enum ConfigError: Error {
    case missingApiKey(String)
}

enum Secrets {
    static var energyDataApiKey: String {
        get throws {
            guard let apiKey = Bundle.main.infoDictionary?["ENERGY_DATA_API_KEY"] as? String else {
                throw ConfigError.missingApiKey("Missing ENERGY_DATA_API_KEY in Secrets.xcconfig")
            }
            return apiKey
        }
    }
}
