//
//  TextRecognizer.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 09/01/2026.
//

import Foundation
import UIKit
import Vision

struct TextRecognizer {
    enum RecognitionError: Error {
        case requestFailed(Error)
        case noResults
    }
    
    let rawImage: CGImage
    let recognizedText: String
    var start: Date? = nil
    var end: Date? = nil
    var chargedEnergy: Measurement<UnitEnergy>? = nil
    var initialSOC: Double? = nil
    var finalSOC: Double? = nil

    init(rawImage: CGImage, recognizedText: String) {
        self.rawImage = rawImage
        self.recognizedText = recognizedText
    }
     
    mutating func analyse() {
        let recognizedText = recognizedText.lowercased()
        
        // Separate by line breaks
        var splitText = Set(recognizedText.components(separatedBy: "\n"))
        
        // Try to identify charged energy by kWh
        if let energyRawString = splitText.first(where: { $0.contains("kwh") }) {
            // Try to parse as number
            if let energyKWh = TextRecognizer.parseLocalizedDouble(energyRawString) {
                self.chargedEnergy = .init(value: energyKWh, unit: .kilowattHours)
            }
            splitText.remove(energyRawString)
        }
        
        // Try to identify charging power
        if let powerRawString = splitText.first(where: { $0.contains("kw") }) {
            // Ensure it's not kWh
            if !powerRawString.contains("kwh") {
                // Just drop, we're not interested in power
                splitText.remove(powerRawString)
            }
        }
        
        // SOC
        if let firstSOCString = splitText.first(where: { $0.contains("%") }) {
            // Try to parse as number
            if let firstSOC = TextRecognizer.parseLocalizedDouble(firstSOCString) {
                splitText.remove(firstSOCString)
                
                // Try to find a second SOC
                if let secondSOCString = splitText.first(where: { $0.contains("%") }) {
                    if let secondSOC = TextRecognizer.parseLocalizedDouble(secondSOCString) {
                        // The higher value is the final SOC
                        self.finalSOC = max(firstSOC, secondSOC)
                        self.initialSOC = min(firstSOC, secondSOC)
                    }
                    splitText.remove(secondSOCString)
                } else {
                    // There probably was only one SOC, the final one
                    self.finalSOC = firstSOC
                }
            }
        }
    }
    
    static func recognizeText(from cgImage: CGImage) throws -> String {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        var recognizedStrings: [String] = []
        var capturedError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }
            if let error = error {
                capturedError = error
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                return
            }
            recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        do {
            try requestHandler.perform([request])
            // Wait for the completion handler to finish populating results
            _ = semaphore.wait(timeout: .now() + 5)
        } catch {
            throw RecognitionError.requestFailed(error)
        }

        if let error = capturedError {
            throw RecognitionError.requestFailed(error)
        }

        guard !recognizedStrings.isEmpty else {
            throw RecognitionError.noResults
        }

        return recognizedStrings.joined(separator: "\n")
    }
    
    // Parse localized numeric string into Double
    static func parseLocalizedDouble(_ raw: String) -> Double? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        
        // Check for percentage
        var isPercentage = false
        if s.contains("%") { isPercentage = true }

        // Remove currency symbols and letters: keep digits, separators, plus/minus
        s = s.filter { "0123456789.,+-".contains($0) }

        // Handle common grouping/decimal conventions
        if s.contains(".") && s.contains(",") {
            // assume "." is thousands separator and "," is decimal (e.g. "1.234,56")
            s = s.replacingOccurrences(of: ".", with: "")
            s = s.replacingOccurrences(of: ",", with: ".")
        } else if s.contains(",") && !s.contains(".") {
            // assume "," is decimal separator
            s = s.replacingOccurrences(of: ",", with: ".")
        }
        
        let doubleValue = Double(s)
        if isPercentage, let doubleValue = doubleValue {
            return doubleValue / 100.0
        } else {
            return doubleValue
        }
    }
}
