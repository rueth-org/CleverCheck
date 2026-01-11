//
//  TextRecognizer.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 09/01/2026.
//

import Foundation
import UIKit
import Vision

class TextRecognizer: Identifiable {
    enum RecognitionError: Error {
        case requestFailed(Error)
        case noResults
    }
    
    enum Confidence: Int, CaseIterable {
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
        let confidence: Confidence
        let value: T
        
        static func == (lhs: TextRecognizer.Candidate<T>, rhs: TextRecognizer.Candidate<T>) -> Bool {
            lhs.confidence.rawValue == rhs.confidence.rawValue
        }
        
        static func < (lhs: TextRecognizer.Candidate<T>, rhs: TextRecognizer.Candidate<T>) -> Bool {
            lhs.confidence.rawValue < rhs.confidence.rawValue
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(confidence)
            hasher.combine(value)
        }
    }
    
    let id = UUID()
    let rawImage: CGImage
    let recognizedText: String
    var start = [Candidate<Date>]()
    var end = [Candidate<Date>]()
    var chargedEnergy = [Candidate<Measurement<UnitEnergy>>]()
    var chargingPower = [Candidate<Measurement<UnitPower>>]()
    var initialSOC = [Candidate<Double>]()
    var finalSOC = [Candidate<Double>]()
    var duration = [Candidate<Duration>]()
    
    private var soc = [Candidate<Double>]()
    private var numberBacklog = [Double]()
    private var indicationStringBacklog = [String]()
    private var otherStringBacklog = [String]()
    
    var report = [String]()

    init(rawImage: CGImage, recognizedText: String) {
        self.rawImage = rawImage
        self.recognizedText = recognizedText
    }
     
    func analyse(for vehicle: Car) {
        report.append(NSLocalizedString("Recognized text:\n\(recognizedText)", comment: ""))
        
        // Separate by line breaks
        let splitText = recognizedText.components(separatedBy: "\n")
        let normalizedText = splitText.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        
        // Evaluate each line
        for text in normalizedText {
            report.append(NSLocalizedString("Evaluating '\(text)'", comment: ""))
            evaluate(text)
        }
        
        // Evaluate backlog
        report.append(NSLocalizedString("Evaluating backlog", comment: ""))
        if indicationStringBacklog.count > 0 {
            // We have some indications, which were not parsed together with their value, e.g., "kWh"
            if numberBacklog.count == indicationStringBacklog.count {
                // Most probably the order of value is matching
                for i in 0..<indicationStringBacklog.count {
                    let indicationString = indicationStringBacklog[i]
                    let value = numberBacklog[i]
                    report.append(NSLocalizedString("Evaluating indication '\(indicationString)' with value \(value)", comment: ""))
                    
                    for indication in Indication.allCases {
                        switch indication {
                        case .energy:
                            if indication.indications.contains(indicationString) {
                                report.append(NSLocalizedString("- Assumed as \(value) kWh with high confidence", comment: ""))
                                chargedEnergy.append(.init(confidence: .high, value: Measurement<UnitEnergy>(value: value, unit: .kilowattHours)))
                            }
                        case .power:
                            if indication.indications.contains(indicationString) {
                                report.append(NSLocalizedString("- Assumed as \(value) kW with high confidence", comment: ""))
                                chargingPower.append(.init(confidence: .high, value: Measurement<UnitPower>(value: value, unit: .kilowatts)))
                            }
                        case .soc:
                            if indication.indications.contains(indicationString) {
                                report.append(NSLocalizedString("- Assumed as \(value * 100)% with high confidence", comment: ""))
                                soc.append(.init(confidence: .high, value: value))
                            }
                        case .duration:
                            if indication.indications.contains(indicationString) {
                                report.append(NSLocalizedString("- Assumed as \(value) minutes with high confidence", comment: ""))
                                let durationInSec = Duration.seconds(value * 60)
                                duration.append(.init(confidence: .high, value: durationInSec))
                            }
                        }
                    }
                }
            } else {
                // Number backlog is not identical, but indication string backlog available
                for indicationString in indicationStringBacklog {
                    for indication in Indication.allCases {
                        switch indication {
                        case .energy:
                            if indication.indications.contains(indicationString) {
                                report.append(NSLocalizedString("Adding the following values as energy with medium confidence:", comment: ""))
                                var possibleValues = numberBacklog
                                // Remove values larger than net battery capacity
                                if let netBatteryCapacityKWh = vehicle.netBatteryCapacityKWh {
                                    possibleValues = numberBacklog.filter { $0 <= netBatteryCapacityKWh }
                                }
                                // Add values to result
                                for possibleValue in possibleValues {
                                    report.append(NSLocalizedString("- \(possibleValue) kWh", comment: ""))
                                    chargedEnergy.append(.init(confidence: .medium, value: Measurement<UnitEnergy>(value: Double(possibleValue), unit: .kilowattHours)))
                                }
                            }
                        case .power:
                            if indication.indications.contains(indicationString) {
                                report.append(NSLocalizedString("Adding the following values as power with medium confidence:", comment: ""))
                                var possibleValues = numberBacklog
                                // Remove values larger than max charging power
                                if let maxChargingPower = vehicle.maxChargingPowerkW {
                                    possibleValues = numberBacklog.filter { $0 <= maxChargingPower }
                                }
                                // Add values to result
                                for possibleValue in possibleValues {
                                    report.append(NSLocalizedString("- \(possibleValue) kW", comment: ""))
                                    chargingPower.append(.init(confidence: .medium, value: Measurement<UnitPower>(value: Double(possibleValue), unit: .kilowatts)))
                                }
                            }
                        case .soc:
                            if indication.indications.contains(indicationString) {
                                report.append(NSLocalizedString("Adding the following values as SOC with medium confidence:", comment: ""))
                                // Remove values larger than 1 and less than 0
                                let possibleValues = numberBacklog.filter { 0 <= $0 && $0 <= 1 }
                                
                                // Add values to result
                                for possibleValue in possibleValues {
                                    report.append(NSLocalizedString("- \(possibleValue * 100)%", comment: ""))
                                    soc.append(.init(confidence: .medium, value: possibleValue))
                                }
                            }
                        case .duration:
                            if indication.indications.contains(indicationString) {
                                report.append(NSLocalizedString("Adding the following values as duration with medium confidence:", comment: ""))
                                for value in numberBacklog {
                                    report.append(NSLocalizedString("- \(value) minutes", comment: ""))
                                    let durationInSec = Duration.seconds(value * 60)
                                    duration.append(.init(confidence: .medium, value: durationInSec))
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // No indication string available, check for number backlog
            if numberBacklog.count == 1 {
                let value = numberBacklog[0]
                
                // We assume the value to be the charged energy
                if let netBatteryCapacityKWh = vehicle.netBatteryCapacityKWh {
                    if value <= netBatteryCapacityKWh {
                        report.append(NSLocalizedString("Adding \(value) kWh with high confidence:", comment: ""))
                        chargedEnergy.append(.init(confidence: .high, value: Measurement<UnitEnergy>(value: value, unit: .kilowattHours)))
                    } else if value/10.0 <= netBatteryCapacityKWh {
                        // There are cases where the decimal separator was not read correctly, so divide by 10 and try again
                        report.append(NSLocalizedString("Dividing \(value)/10 and adding \(value/10.0) kWh with medium confidence:", comment: ""))
                        chargedEnergy.append(.init(confidence: .medium, value: Measurement<UnitEnergy>(value: value/10.0, unit: .kilowattHours)))
                    }
                } else {
                    // We simply add the value
                    report.append(NSLocalizedString("Adding \(value) kWh with low confidence:", comment: ""))
                    chargedEnergy.append(.init(confidence: .low, value: Measurement<UnitEnergy>(value: value, unit: .kilowattHours)))
                }
            }
        }
        
        // Check sanity
        checkSanity(for: vehicle)
        
        // Adding ignored strings to report
        report.append(NSLocalizedString("Ignored the following strings:\n\(otherStringBacklog.joined(separator: "\n"))", comment: ""))
    }
    
    private func evaluate(_ text: String) {
        var success = false
        for indication in Indication.allCases {
            if TextRecognizer.containsAnyIndication(in: text, indications: indication.indications) {
                // The text contains an indication, try to extract the number
                switch indication {
                case .energy:
                    report.append(NSLocalizedString("- Identified as energy", comment: ""))
                    // Try to parse as number
                    if let value = TextRecognizer.parseLocalizedDouble(text) {
                        report.append(NSLocalizedString("- Parsed as \(value) kWh with very high confidence", comment: ""))
                        // There was a number alongside the indication
                        chargedEnergy.append(.init(
                            confidence: .veryHigh,
                            value: Measurement<UnitEnergy>(value: value, unit: .kilowattHours)
                        ))
                    } else {
                        report.append(NSLocalizedString("- Could not parse as number, adding to backlog", comment: ""))
                        indicationStringBacklog.append(text)
                    }
                    success = true
                case .power:
                    // Make sure it's not energy, as kW is a substring of kWh
                    if !TextRecognizer.containsAnyIndication(in: text, indications: Indication.energy.indications) {
                        report.append(NSLocalizedString("- Identified as power", comment: ""))
                        // Try to parse as number
                        if let value = TextRecognizer.parseLocalizedDouble(text) {
                            report.append(NSLocalizedString("- Parsed as \(value) kW with very high confidence", comment: ""))
                            // There was a number alongside the indication
                            chargingPower.append(.init(
                                confidence: .veryHigh,
                                value: Measurement<UnitPower>(value: value, unit: .kilowatts)
                            ))
                        } else {
                            report.append(NSLocalizedString("- Could not parse as number, adding to backlog", comment: ""))
                            indicationStringBacklog.append(text)
                        }
                        success = true
                    }
                case .soc:
                    report.append(NSLocalizedString("- Identified as SOC", comment: ""))
                    // We might see two percentages - one initial SOC, one final SOC - in one line
                    // Therefore we first split by percentage sign
                    let parts = text.components(separatedBy: "%")
                    for part in parts {
                        if !part.isEmpty {
                            if let value = TextRecognizer.parseLocalizedDouble(String(part)) {
                                if value > 0.0 && value <= 100.0 {
                                    report.append(NSLocalizedString("- Parsed as \(value)% with very high confidence", comment: ""))
                                    soc.append(.init(confidence: .veryHigh, value: value/100.0))
                                } else {
                                    report.append(NSLocalizedString("- Could not parse as valid percentage, adding to backlog", comment: ""))
                                    numberBacklog.append(value)
                                }
                            } else {
                                report.append(NSLocalizedString("- Could not parse as number, adding to backlog", comment: ""))
                                indicationStringBacklog.append(text)
                            }
                            success = true
                        }
                    }
                case .duration:
                    report.append(NSLocalizedString("- Identified as duration", comment: ""))
                    // Try to parse as time
                    if let value = TextRecognizer.parseDuration(text) {
                        report.append(NSLocalizedString("- Parsed as \(value.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 0)))) with very high confidence", comment: ""))
                        // A duration was identified
                        duration.append(.init(
                            confidence: .veryHigh,
                            value: value
                        ))
                    } else {
                        report.append(NSLocalizedString("- Could not parse as duration, adding to backlog", comment: ""))
                        indicationStringBacklog.append(text)
                    }
                    success = true
                }
            }
        }
        
        if !success {
            // No indication was found, so check the text for a number and put it in the backlog
            report.append(NSLocalizedString("- No indication for a certain type found, adding to backlog", comment: ""))
            if let number = TextRecognizer.parseLocalizedDouble(text) {
                numberBacklog.append(number)
            } else {
                otherStringBacklog.append(text)
            }
        }
    }
    
    private func checkSanity(for vehicle: Car) {
        // Check sanity of charged energy
        report.append(NSLocalizedString("Checking sanity of energy candidates...", comment: ""))
        if chargedEnergy.count > 1 {
            var candidates = Set(chargedEnergy)
            if let netBatteryCapacityKWh = vehicle.netBatteryCapacityKWh {
                // Charging more than the vehicle's net capacity is impossible
                let impossible = candidates.filter { $0.value.converted(to: .kilowattHours).value > netBatteryCapacityKWh }
                report.append(NSLocalizedString("- Removing \(impossible.count) candidate(s) exceeding net battery capacity of \(netBatteryCapacityKWh) kWh.", comment: ""))
                remove(impossible, from: &candidates)
                
                if candidates.count > 1 {
                    // We still have more than 1 candidate
                    // We rarely charge more than 80% of the net capacity
                    let unlikely = candidates.filter { $0.value.converted(to: .kilowattHours).value > netBatteryCapacityKWh * 0.8 }
                    report.append(NSLocalizedString("- Marking \(unlikely.count) candidate(s) with more than 80% of net battery capacity as low confidence", comment: ""))
                    // Mark those with low confidence by creating new candidates with .low confidence
                    candidates = Set(candidates.map { candidate in
                        if unlikely.contains(candidate) {
                            return Candidate(confidence: .low, value: candidate.value)
                        } else {
                            return candidate
                        }
                    })
                    chargedEnergy = Array(candidates).sorted()
                }
            }
        } else if chargedEnergy.count == 1 {
            report.append(NSLocalizedString("- One candidate found", comment: ""))
            
            // Check for net capacity
            if let netBatteryCapacityKWh = vehicle.netBatteryCapacityKWh {
                if chargedEnergy[0].value.value > netBatteryCapacityKWh {
                    report.append(NSLocalizedString("- Candidate (\(chargedEnergy[0].value.value) kWh) larger than the net battery capacity of \(netBatteryCapacityKWh) kWh removed.", comment: ""))
                    chargedEnergy.remove(at: 0)
                }
            }
        }
        
        // Check sanity of charging power
        report.append(NSLocalizedString("Checking sanity of power candidates...", comment: ""))
        if chargingPower.count > 1 {
            var candidates = Set(chargingPower)
            if let maxChargingPowerKW = vehicle.maxChargingPowerkW {
                // Charging more than the vehicle's max charging power is impossible
                let impossible = candidates.filter { $0.value.converted(to: .kilowatts).value > maxChargingPowerKW }
                report.append(NSLocalizedString("- Removing \(impossible.count) candidate(s) exceeding max charging power of \(maxChargingPowerKW) kW.", comment: ""))
                remove(impossible, from: &candidates)
                
                if candidates.count > 1 {
                    // We still have more than 1 candidate
                    // We rarely charge with more than 80% of the max power
                    let unlikely = candidates.filter { $0.value.converted(to: .kilowatts).value > maxChargingPowerKW * 0.8 }
                    report.append(NSLocalizedString("- Marking \(unlikely.count) candidate(s) with more than 80% of max charging power as low confidence", comment: ""))
                    // Mark those with low confidence by creating new candidates with .low confidence
                    candidates = Set(candidates.map { candidate in
                        if unlikely.contains(candidate) {
                            return Candidate(confidence: .low, value: candidate.value)
                        } else {
                            return candidate
                        }
                    })
                    chargingPower = Array(candidates).sorted()
                }
            }
        } else if chargingPower.count == 1 {
            report.append(NSLocalizedString("- One candidate found", comment: ""))
            
            // Check for max charging power
            if let maxChargingPower = vehicle.maxChargingPowerkW {
                if chargingPower[0].value.value > maxChargingPower {
                    report.append(NSLocalizedString("- Candidate (\(chargingPower[0].value.value) kW) larger than the max charging power of \(maxChargingPower) kW removed.", comment: ""))
                    chargingPower.remove(at: 0)
                }
            }
        }
        
        // Check sanity of SOC
        report.append(NSLocalizedString("Checking sanity of SOC candidates...", comment: ""))
        
        // Get all candidates with very high confidence
        let veryHighSOC = soc.filter { $0.confidence == .veryHigh }
        report.append(NSLocalizedString("- \(veryHighSOC.count) candidates with very high confidence found.", comment: ""))
        setSOC(veryHighSOC)
        
        // Add candidates with high confidence
        let highSOC = soc.filter { $0.confidence == .high }
        report.append(NSLocalizedString("- \(highSOC.count) candidates with high confidence found.", comment: ""))
        setSOC(highSOC)
        
        let mediumSOC = soc.filter { $0.confidence == .medium }
        report.append(NSLocalizedString("- \(mediumSOC.count) candidates with medium confidence found.", comment: ""))
        setSOC(mediumSOC)
        
        let lowSOC = soc.filter { $0.confidence == .low }
        report.append(NSLocalizedString("- \(lowSOC.count) candidates with low confidence found.", comment: ""))
        setSOC(lowSOC)
    }
    
    private func setSOC(_ candidates: [Candidate<Double>]) {
        let sortedCandidates = candidates.sorted(by: { $0.value < $1.value })
        if sortedCandidates.count == 1 {
            report.append(NSLocalizedString("- Setting \(sortedCandidates[0].value * 100)% as final SOC.", comment: ""))
            self.finalSOC.append(contentsOf: sortedCandidates)
        } else if sortedCandidates.count == 2 {
            report.append(NSLocalizedString("- Setting \(sortedCandidates[0].value * 100)% as initial SOC.", comment: ""))
            self.initialSOC.append(sortedCandidates[0])
            report.append(NSLocalizedString("- Setting \(sortedCandidates[1].value * 100)% as final SOC.", comment: ""))
            self.finalSOC.append(sortedCandidates[1])
        } else {
            // Add all candidates to both
            report.append(NSLocalizedString("- Adding all values to both initial and final SOC.", comment: ""))
            self.initialSOC.append(contentsOf: sortedCandidates)
            self.finalSOC.append(contentsOf: sortedCandidates)
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
