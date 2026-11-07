//
//  APIClient.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 06/11/2026.
//

import Foundation

final class EnergyDataAPIClient {
    private let baseUrlString = "https://energydata.rueth.info/api.php/records"
    private let apiKey = Secrets.energyDataApiKey
    private let session = URLSession.shared

    func request(
        path: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws -> Data {
        guard let baseUrl = URL(string: baseUrlString) else {
            throw EnergyDataService.EnergyDataError.invalidURL(baseUrlString)
        }
        var url = baseUrl.appending(
            path: path
        )
        
        if let queryItems {
            url.append(queryItems: queryItems)
        }

        var request = URLRequest(url: url)

        request.httpMethod = method
        request.httpBody = body

        request.setValue(
            apiKey,
            forHTTPHeaderField: "X-API-Key"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }
}
