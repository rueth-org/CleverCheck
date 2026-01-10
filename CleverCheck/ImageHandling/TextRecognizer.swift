//
//  TextRecognizer.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 09/01/2026.
//

import Foundation
import UIKit
import Vision

class TextRecognizer {
    enum RecognitionError: Error {
        case requestFailed(Error)
        case noResults
    }
    
    enum Probability: Int, CaseIterable {
        case veryHigh = 0, high, medium, low
    }
    
    enum Indication: CaseIterable {
        case energy, power, soc, duration
        
        var indications: [String] {
            switch self {
            case .energy: return ["kwh", "kilowatthours"]
            case .power: return ["kw", "kilowatt"]
            case .soc: return ["%", "soc", "state of charge"]
            case .duration: return [":", "min", "minutes"]
            }
        }
    }
    
    struct Candidate<T: Hashable>: Comparable, Hashable {
        let probability: Probability
        let value: T
        
        static func == (lhs: TextRecognizer.Candidate<T>, rhs: TextRecognizer.Candidate<T>) -> Bool {
            lhs.probability.rawValue == rhs.probability.rawValue
        }
        
        static func < (lhs: TextRecognizer.Candidate<T>, rhs: TextRecognizer.Candidate<T>) -> Bool {
            lhs.probability.rawValue < rhs.probability.rawValue
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(probability)
            hasher.combine(value)
        }
    }
    
    let rawImage: CGImage
    let recognizedText: String
    var start = [Candidate<Date>]()
    var end = [Candidate<Date>]()
    var chargedEnergy = [Candidate<Measurement<UnitEnergy>>]()
    var chargingPower = [Candidate<Measurement<UnitPower>>]()
    var initialSOC = [Candidate<Double>]()
    var finalSOC = [Candidate<Double>]()
    var duration = [Candidate<Duration>]()

    init(rawImage: CGImage, recognizedText: String) {
        self.rawImage = rawImage
        self.recognizedText = recognizedText
    }
     
    func analyse(for vehicle: Car) {
        // Separate by line breaks
        let splitText = recognizedText.components(separatedBy: "\n")
        
        // Evaluate each line
        for text in splitText {
            evaluate(text)
        }
        
        // Check sanity of charged energy
        if chargedEnergy.count > 1 {
            var candidates = Set(chargedEnergy)
            if let netBatteryCapacityKWh = vehicle.netBatteryCapacityKWh {
                // Charging more than the vehicle's net capacity is impossible
                let impossible = candidates.filter { $0.value.converted(to: .kilowattHours).value > netBatteryCapacityKWh }
                remove(impossible, from: &candidates)
                
                if candidates.count > 1 {
                    // We still have more than 1 candidate
                    // We rarely charge more than 80% of the net capacity
                    let unlikely = candidates.filter { $0.value.converted(to: .kilowattHours).value > netBatteryCapacityKWh * 0.8 }
                    // Mark those with low probability by creating new candidates with .low probability
                    candidates = Set(candidates.map { candidate in
                        if unlikely.contains(candidate) {
                            return Candidate(probability: .low, value: candidate.value)
                        } else {
                            return candidate
                        }
                    })
                    chargedEnergy = Array(candidates).sorted()
                }
            }
        }
        
        // Check sanity of charging power
        if chargingPower.count > 1 {
            var candidates = Set(chargingPower)
            if let maxChargingPowerKW = vehicle.maxChargingPowerkW {
                // Charging more than the vehicle's max charging power is impossible
                let impossible = candidates.filter { $0.value.converted(to: .kilowatts).value > maxChargingPowerKW }
                remove(impossible, from: &candidates)
                
                if candidates.count > 1 {
                    // We still have more than 1 candidate
                    // We rarely charge with more than 80% of the max power
                    let unlikely = candidates.filter { $0.value.converted(to: .kilowatts).value > maxChargingPowerKW * 0.8 }
                    // Mark those with low probability by creating new candidates with .low probability
                    candidates = Set(candidates.map { candidate in
                        if unlikely.contains(candidate) {
                            return Candidate(probability: .low, value: candidate.value)
                        } else {
                            return candidate
                        }
                    })
                    chargingPower = Array(candidates).sorted()
                }
            }
        }
        
        // Check sanity of SOC
        // Get all SOC values
        let initialSOC = Set(self.initialSOC.map { $0.value })
        let finalSOC = Set(self.finalSOC.map { $0.value })
        
        // This will remove all duplicates
        let unionizedSOC = initialSOC.union(finalSOC)
        
        // Exclude all impossible SOC
        let allSOC = unionizedSOC.filter { $0 >= 0 && $0 <= 1 }
        
        if allSOC.count == 0 {
            self.initialSOC = []
            self.finalSOC = []
        } else if allSOC.count == 1 {
            self.finalSOC = [Candidate<Double>(probability: .veryHigh, value: allSOC.first!)]
        } else if allSOC.count == 2 {
            if let first = allSOC.first, let second = allSOC.subtracting([first]).first {
                if first < second {
                    self.initialSOC = [Candidate<Double>(probability: .veryHigh, value: first)]
                    self.finalSOC = [Candidate<Double>(probability: .veryHigh, value: second)]
                } else {
                    self.finalSOC = [Candidate<Double>(probability: .veryHigh, value: first)]
                    self.initialSOC = [Candidate<Double>(probability: .veryHigh, value: second)]
                }
            }
        }
    }
    
    private func evaluate(_ text: String) {
        for indication in Indication.allCases {
            if TextRecognizer.containsAnyIndication(in: text, indications: indication.indications) {
                // The text contains an indication, try to extract the number
                switch indication {
                case .energy:
                    // Try to parse as number
                    if let value = TextRecognizer.parseLocalizedDouble(text) {
                        // There was a number alongside the indication
                        chargedEnergy.append(.init(
                            probability: .veryHigh,
                            value: Measurement<UnitEnergy>(value: value, unit: .kilowattHours)
                        ))
                    }
                case .power:
                    // Make sure it's not energy, as kW is a substring of kWh
                    if !TextRecognizer.containsAnyIndication(in: text, indications: Indication.energy.indications) {
                        // Try to parse as number
                        if let value = TextRecognizer.parseLocalizedDouble(text) {
                            // There was a number alongside the indication
                            chargingPower.append(.init(
                                probability: .veryHigh,
                                value: Measurement<UnitPower>(value: value, unit: .kilowatts)
                            ))
                        }
                    }
                case .soc:
                    // We might see two percentages - one initial SOC, one final SOC - in one line
                    let percentSignCount = text.filter { $0 == "%" }.count
                    
                    if percentSignCount <= 1 {
                        // Try to parse as number
                        if let value = TextRecognizer.parseLocalizedDouble(text) {
                            // There was a number alongside the indication
                            let soc = Candidate<Double>(
                                probability: .veryHigh,
                                value: value
                            )
                            
                            // Assign it to both initial and final SOC, we sort it out later
                            initialSOC.append(soc)
                            finalSOC.append(soc)
                        }
                    } else if percentSignCount == 2 {
                        // Split at the percent sign
                        let parts = text.components(separatedBy: "%")
                        
                        if parts.count >= 2 {
                            // We assume the first part and the second part to be the percentages
                            if let value1 = TextRecognizer.parseLocalizedDouble(String(parts[0])),
                               let value2 = TextRecognizer.parseLocalizedDouble(String(parts[1]))
                            {
                                if value1 == value2 {
                                    initialSOC.append(Candidate<Double>(probability: .veryHigh, value: value1 / 100))
                                    finalSOC.append(Candidate<Double>(probability: .veryHigh, value: value1 / 100))
                                } else if value1 < value2 {
                                    initialSOC.append(Candidate<Double>(probability: .veryHigh, value: value1 / 100))
                                    finalSOC.append(Candidate<Double>(probability: .veryHigh, value: value2 / 100))
                                } else {
                                    initialSOC.append(Candidate<Double>(probability: .veryHigh, value: value2 / 100))
                                    finalSOC.append(Candidate<Double>(probability: .veryHigh, value: value1 / 100))
                                }
                            }
                        }
                    }
                case .duration:
                    // Try to parse as time
                    if let value = TextRecognizer.parseDuration(text) {
                        // A duration was identified
                        duration.append(.init(
                            probability: .veryHigh,
                            value: value
                        ))
                    }
                }
            }
        }
    }
    
    private func remove<T>(_ values: Set<Candidate<T>>, from: inout Set<Candidate<T>>) {
        for v in values {
            from.remove(v)
        }
    }
    
    /// Returns true if any of the provided `indications` is found as a substring of `text`.
    /// Matching is case-insensitive and diacritic-insensitive.
    ///
    /// - Parameters:
    ///   - text: The full text to search in.
    ///   - indications: Array of substrings to look for inside `text`.
    /// - Returns: `true` if any indication is contained in `text`, otherwise `false`.
    static func containsAnyIndication(in text: String, indications: [String]) -> Bool {
        // Line ~116: core matching logic
        // Normalize the text once: remove diacritics, normalize width and lower-case for robust matching.
        let normalizedText = text.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current).lowercased()

        for raw in indications {
            let needle = NSLocalizedString(raw, comment: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
                .lowercased()

            // Skip empty needles
            if needle.isEmpty { continue }

            if normalizedText.contains(needle) {
                return true
            }
        }

        return false
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
    
    // Pars string into duration
    static func parseDuration(_ raw: String) -> Duration? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        
        // Remove any symbols and letters: keep digits, colons
        s = s.filter { "0123456789:".contains($0) }
        
        // Identify number of colons
        let colonCount = s.filter { $0 == ":" }.count
        
        if colonCount == 0 {
            // There seem to be minutes only
            if let minutes = TextRecognizer.parseLocalizedDouble(s) {
                // Successfully parsed value
                return Duration.seconds(minutes * 60)
            } else {
                // No number parsed
                return nil
            }
        } else {
            // Split into parts
            let parts = s.components(separatedBy: ":")
            
            if parts.count == 2 {
                // There are two parts, one before and one after the colong
                if let part1 = TextRecognizer.parseLocalizedDouble(parts[0]), let part2 = TextRecognizer.parseLocalizedDouble(parts[1]) {
                    if part1 == 0 {
                        // If part 1 = 0, then it represents most likely hours and part 2 minutes
                        return Duration.seconds(part1 * 3600 + part2 * 60)
                    } else {
                        // If part 1 other than 0, then it represents most likely minutes and part 2 seconds
                        return Duration.seconds(part1 * 60 + part2)
                    }
                } else {
                    return nil
                }
            } else if parts.count == 3 {
                if let part1 = TextRecognizer.parseLocalizedDouble(parts[0]), let part2 = TextRecognizer.parseLocalizedDouble(parts[1]), let part3 = TextRecognizer.parseLocalizedDouble(parts[2]) {
                    // Part 1 are hours, part 2 minutes, part 3 seconds
                    return Duration.seconds(part1 * 3600 + part2 * 60 + part3)
                } else {
                    return nil
                }
            } else {
                // Cannot interprete more than 3 parts
                return nil
            }
        }
    }
}

