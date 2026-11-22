//
//  HomeConsumption.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 30/11/2025.
//

import Foundation
import SwiftData

@Model
final class HomeConsumption: Comparable {
    enum ConsumptionType: String, Codable, CustomStringConvertible, CaseIterable {
        case total = "Total consumption"
        case home = "Home consumption"
        case homeRefunded = "Refunded home consumption"
        case homeDiscount = "Discount on home consumption"
        case charging = "Charging"
        case chargingRefunded = "Refunded charging"
        case chargingDiscount = "Discount on charging"
        case refundingOtherPlan = "Refunding for other plan"
        
        var description: String {
            NSLocalizedString(self.rawValue, comment: "")
        }
    }
    
    /// Switch between value sources. 'Invoice' always uses the values directly entered in the price elements, 'calculated' the seasonal or public values, 'automatic' the calculated ones when available, otherwise from invoice.
    enum ValueSource: String, Codable, CaseIterable {
        case invoice
        case calculated
        case automatic
    }
    
    struct PowerPrices: Codable {
        let currency: String
        let includingVAT: Bool
        let granularity: PowerPriceGranularity
        var fixedPrices: [Date: [String: Double]]
        var variablePrices: [Date: [String: Double]]
        
        /// Returns the fixed and variable prices for a given date, considering whether to include VAT or not. If no prices are found for the given date, it returns empty dictionaries and a sum of 0.0.
        /// - Parameters:
        ///   - date: The date for which to retrieve the prices.
        ///   - includingVAT: A boolean indicating whether to include VAT in the returned prices.
        /// - Returns: A tuple containing the fixed prices, variable prices, and their sum for the given date.
        func getPrices(for date: Date, includingVAT: Bool) -> (fixed: [String: Double], variable: [String: Double], sum: Double) {
            var fixed = [String: Double]()
            let sortedFixedPrices = fixedPrices.sorted { $0.key < $1.key }
            for (priceDate, prices) in sortedFixedPrices {
                if date >= priceDate {
                    // Convert prices if includingVAT is different from the stored prices
                    fixed = prices.mapValues { priceConsideringVAT(for: $0, includingVAT: includingVAT) }
                } else {
                    break
                }
            }
            
            var variable = [String: Double]()
            let sortedVariablePrices = variablePrices.sorted { $0.key < $1.key }
            for (priceDate, prices) in sortedVariablePrices {
                if date >= priceDate {
                    // Convert prices if includingVAT is different from the stored prices
                    variable = prices.mapValues { priceConsideringVAT(for: $0, includingVAT: includingVAT) }
                } else {
                    break
                }
            }
            
            let sum = fixed.values.reduce(0.0, +) + variable.values.reduce(0.0, +)
            return (fixed: fixed, variable: variable, sum: sum)
        }
        
        /// Returns all fixed and variable prices for all dates, considering whether to include VAT or not. If no prices are found for a given date, it returns empty dictionaries and a sum of 0.0.
        /// - Parameter includingVAT: A boolean indicating whether to include VAT in the returned prices.
        /// - Returns: A dictionary mapping dates to tuples containing the fixed prices, variable prices, and their sum.
        func getAllPrices(includingVAT: Bool) -> [Date: (fixed: [String: Double], variable: [String: Double], sum: Double)] {
            let sortedDates = Set(fixedPrices.keys).union(variablePrices.keys).sorted()
            return sortedDates.reduce(into: [:]) { result, date in
                result[date] = getPrices(for: date, includingVAT: includingVAT)
            }
        }

        mutating func updatePrices(
            for homeConsumption: HomeConsumption,
            resolutionMinutes: Int,
            validFrom: Date? = nil,
            validTo: Date? = nil
        ) async throws {
            let rangeStart = validFrom ?? homeConsumption.validFrom
            let rangeEnd = validTo ?? homeConsumption.validUntil

            let updatedPriceBlocks = try await costPerKWh(
                for: homeConsumption,
                startTime: rangeStart,
                endTime: rangeEnd,
                resolutionMinutes: resolutionMinutes
            )

            fixedPrices = fixedPrices.filter { $0.key < rangeStart || $0.key > rangeEnd }
            variablePrices = variablePrices.filter { $0.key < rangeStart || $0.key > rangeEnd }

            for (timestamp, prices) in updatedPriceBlocks {
                fixedPrices[timestamp] = prices.fixed.mapValues { convertedAmount(of: $0) }
                variablePrices[timestamp] = prices.variable.mapValues { convertedAmount(of: $0) }
            }
        }

        func costPerKWh(
            for homeConsumption: HomeConsumption,
            startTime: Date,
            endTime: Date,
            resolutionMinutes: Int
        ) async throws -> [Date: (fixed: [String: Cost], variable: [String: Cost])] {
            guard let location = homeConsumption.associatedLocation else {
                throw EnergyDataService.EnergyDataError.noLocation
            }

            let totalDuration = homeConsumption.validUntil.timeIntervalSince(homeConsumption.validFrom)
            guard totalDuration > 0 else {
                throw EnergyDataService.EnergyDataError.cannotDetermineDuration
            }

            guard let priceElements = homeConsumption.priceElements else {
                return [:]
            }
            let includedPriceElements = priceElements.filter { $0.excludeFromSimulation == false }

            let priceElementsOnce = includedPriceElements.filter {
                if case .once = $0.type { return true } else { return false }
            }
            let priceElementsDaily = includedPriceElements.filter {
                if case .daily = $0.type { return true } else { return false }
            }
            let priceElementsSpecific = includedPriceElements.filter {
                if case .byConsumption(_) = $0.type { return true } else { return false }
            }

            let energyDataService = EnergyDataService.shared
            let energyPrices = try await energyDataService.dayAheadPrices(for: location, from: startTime, to: endTime)

            let intervalSeconds = 60 * Double(resolutionMinutes)
            var currentTime = startTime
            var result = [Date: (fixed: [String: Cost], variable: [String: Cost])]()

            while currentTime < endTime {
                var fixedEntries = [String: Cost]()

                let proportion = intervalSeconds / totalDuration
                for priceElement in priceElementsOnce {
                    fixedEntries[priceElement.label] = Cost(
                        amount: priceElement.getConvertedCost(valueSource: .calculated, includingVAT: includingVAT).amount * proportion,
                        currency: currency
                    )
                }

                let dailyProportion = intervalSeconds / 86_400
                for priceElement in priceElementsDaily {
                    fixedEntries[priceElement.label] = Cost(
                        amount: priceElement.getConvertedCost(valueSource: .calculated, includingVAT: includingVAT).amount * dailyProportion,
                        currency: currency
                    )
                }

                var variableEntries = [String: Cost]()

                if let price = energyPrices.first(where: {
                    $0.timeUTC <= currentTime &&
                    currentTime < $0.timeUTC.addingTimeInterval(Double($0.granularity.resolutionMinutes) * 60)
                }) {
                    variableEntries[NSLocalizedString("Power Price", comment: "")] = price.pricePerKWh.converted(to: currency) ?? price.pricePerKWh
                } else {
                    throw EnergyDataService.EnergyDataError.notFound("No energy price found for time \(currentTime)")
                }

                let tempEndTime = currentTime.addingTimeInterval(intervalSeconds)
                for priceElement in priceElementsSpecific {
                    let seasonalCost = priceElement.getConvertedCost(
                        valueSource: .calculated,
                        includingVAT: includingVAT,
                        startTime: currentTime,
                        endTime: tempEndTime
                    )
                    variableEntries[priceElement.label] = seasonalCost.converted(to: currency) ?? seasonalCost
                }

                result[currentTime] = (fixed: fixedEntries, variable: variableEntries)
                currentTime = currentTime.addingTimeInterval(intervalSeconds)
            }

            return result
        }
        
        private func priceConsideringVAT(for price: Double, includingVAT: Bool) -> Double {
            if includingVAT && !self.includingVAT {
                return price * UserSettings.shared.vatRate
            } else if !includingVAT && self.includingVAT {
                return price / UserSettings.shared.vatRate
            } else {
                return price
            }
        }

        private func convertedAmount(of cost: Cost) -> Double {
            cost.converted(to: currency)?.amount ?? cost.amount
        }
    }
    
    struct PowerConsumptions: Codable {
        let granularity: PowerPriceGranularity
        var consumptionsKWh: [Date: Double]
        
        var consumptions: [Date: Measurement<UnitEnergy>] {
            consumptionsKWh.mapValues { Measurement<UnitEnergy>(value: $0, unit: .kilowattHours) }
        }
        
        func consumption(at date: Date) -> Measurement<UnitEnergy>? {
            // Iterate through the sorted dates of consumptionsKWh and find the consumption where the given date is larger or equal
            let sortedDates = consumptionsKWh.keys.sorted()
            for consumptionDate in sortedDates {
                if date >= consumptionDate {
                    return .init(value: consumptionsKWh[consumptionDate] ?? 0.0, unit: .kilowattHours)
                } else {
                    break
                }
            }
            return nil
        }
        
        func consumption(from startDate: Date, to endDate: Date) -> Measurement<UnitEnergy> {
            let sortedDates = consumptionsKWh.keys.sorted()
            var totalConsumption: Double = 0.0
            for consumptionDate in sortedDates {
                if consumptionDate >= startDate && consumptionDate <= endDate {
                    totalConsumption += consumptionsKWh[consumptionDate] ?? 0.0
                }
            }
            return .init(value: totalConsumption, unit: .kilowattHours)
        }
        
        func consumption(in monthString: String) -> Measurement<UnitEnergy> {
            let totalConsumption = consumptionsKWh.filter {
                monthString == UserSettings.shared.groupingDateFormatter.string(from: $0.key)
            }.reduce(0.0) { $0 + $1.value }
            return .init(value: totalConsumption, unit: .kilowattHours)
        }
    }
    
    var id: UUID = UUID()
    var name: String = ""
    var validFrom: Date = Date.now.startOfMonth
    var validUntil: Date = Date.now.endOfMonth
    var consumptionKWh: Double = 0.0
    var consumptionType: ConsumptionType = ConsumptionType.total
    var associatedLocation: Location?
    var prices: PowerPrices? = nil
    var consumptions: PowerConsumptions? = nil
    var defaultToEnteredConsumption: Bool = true
    var comment: String = ""
    
    @Relationship(deleteRule: .cascade, inverse: \PriceElement.homeConsumption)
    var priceElements: [PriceElement]?
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingSession.relatedHomeConsumption)
    var chargingSessions: [ChargingSession]?
    
    @Relationship(deleteRule: .nullify, inverse: \ChargingSession.relatedRefundingHomeConsumption)
    var refundedChargingSessions: [ChargingSession]?
    
    var dataFromRelatedChargingSessions: (consumption: Measurement<UnitEnergy>, directCost: Cost, estimatedRealCost: Cost)? {
        if let chargingSessions, !chargingSessions.isEmpty {
            // Consumption
            let consumptions = chargingSessions.compactMap { $0.chargedEnergyKWh }
            let totalConsumption = consumptions.reduce(0.0, +)
            
            // Direct cost
            let directCost = chargingSessions.compactMap { $0.chargingCost }
            let totalDirectCost = directCost.reduce(.init(amount: 0.0)) { $0 + $1 }
            
            // Estimated real cost
            let estimatedRealCost = chargingSessions.compactMap { $0.estimatedRealCost }
            let totalEstimatedRealCost = estimatedRealCost.reduce(.init(amount: 0.0)) { $0 + $1 }
            
            return (Measurement<UnitEnergy>(value: totalConsumption, unit: .kilowattHours), totalDirectCost, totalEstimatedRealCost)
        } else {
            return nil
        }
    }
    
    var dataFromRelatedRefundedChargingSessions: (consumption: Measurement<UnitEnergy>, directCost: Cost, estimatedRealCost: Cost)? {
        if let refundedChargingSessions, !refundedChargingSessions.isEmpty {
            // Consumption
            let consumptions = refundedChargingSessions.compactMap { $0.chargedEnergyKWh }
            let totalConsumption = consumptions.reduce(0.0, +)
            
            // Direct cost
            let directCost = refundedChargingSessions.compactMap { $0.chargingCost }
            let totalDirectCost = directCost.reduce(.init(amount: 0.0)) { $0 + $1 }
            
            // Estimated real cost
            let estimatedRealCost = refundedChargingSessions.compactMap { $0.estimatedRealCost }
            let totalEstimatedRealCost = estimatedRealCost.reduce(.init(amount: 0.0)) { $0 + $1 }
            
            return (Measurement<UnitEnergy>(value: totalConsumption, unit: .kilowattHours), totalDirectCost, totalEstimatedRealCost)
        } else {
            return nil
        }
    }
    
    @Transient var consumption: Measurement<UnitEnergy> {
        get {
            return Measurement<UnitEnergy>(value: consumptionKWh, unit: .kilowattHours)
        }
        set {
            consumptionKWh = newValue.converted(to: .kilowattHours).value
        }
    }
    
    var description: String {
        if associatedLocation != nil {
            return "\(name) (\(associatedLocation!.name))"
        } else {
            return "\(name)"
        }
    }
    
    var descriptionWithDate: String {
        let dateFormatter = DateFormatter().shortMonthYear
        return "\(description) (\(dateFormatter.string(from: validUntil)))"
    }
    
    /// Calculates the number of days covered in each month within the validFrom to validUntil range.
    private var daysPerMonth: [String: Int] {
        let calendar = Calendar.current
        
        // Determine the number of days for each of the covered months, and store them in a dictionary
        var daysPerMonth: [String: Int] = [:]
        var currentDate = validFrom
        while currentDate <= validUntil {
            let monthKey = UserSettings.shared.groupingDateFormatter.string(from: currentDate)
            
            // Determine the start of the month and next month
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate))!
            guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                break
            }
            
            // Determine if currentDate is later than the first day of the month
            let monthStartDate = currentDate > startOfMonth ? currentDate : startOfMonth
            
            // Determine if validUntil is earlier than the last day of the month
            let monthEndDate = validUntil < endOfMonth ? validUntil : endOfMonth.addingTimeInterval(-1)
            
            // Calculate the number of days in this month portion
            let components = calendar.dateComponents([.day], from: monthStartDate, to: monthEndDate)
            daysPerMonth[monthKey] = (components.day ?? 0) + 1
            
            // Move to the next month
            currentDate = endOfMonth
        }
        
        return daysPerMonth
    }
    
    private var numberOfDays: Int {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: validFrom)
        let endDate = calendar.startOfDay(for: validUntil)
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }
    
    var measuredVsContractualDifference: Measurement<UnitEnergy>? {
        guard let measured = measuredConsumptionKWh() else { return nil }
        return Measurement(value: measured - contractualConsumptionKWh(), unit: .kilowattHours)
    }
    
    init(
        name: String,
        validFrom: Date,
        validUntil: Date,
        consumption: Measurement<UnitEnergy>,
        consumptionType: ConsumptionType = .total,
        associatedLocation: Location? = nil,
        comment: String? = nil
    ) {
        self.name = name
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.consumptionKWh = consumption.converted(to: .kilowattHours).value
        self.consumptionType = consumptionType
        self.associatedLocation = associatedLocation
        if let comment {
            self.comment = comment
        }
    }
    
    private func contractualConsumptionKWh() -> Double {
        max(consumptionKWh, 0.0)
    }

    private func measuredConsumptionKWh() -> Double? {
        guard let consumptions else { return nil }
        // If `consumptionsKWh` are period amounts, sum is correct.
        // If they are snapshots, adjust logic before enabling this in production.
        let total = consumptions.consumptionsKWh.reduce(0.0) { $0 + $1.value }
        return max(total, 0.0)
    }

    private func consumptionKWh(for source: ValueSource) -> Double {
        switch source {
        case .invoice:
            return contractualConsumptionKWh()
        case .calculated:
            return measuredConsumptionKWh() ?? 0.0
        case .automatic:
            return measuredConsumptionKWh() ?? contractualConsumptionKWh()
        }
    }
    
    /// Returns the consumption for the home consumption, either using the entered consumption or the consumption from related charging sessions.
    /// - Parameter useRelatedConsumptions: If true, the consumption from related charging sessions is used instead of the entered consumption. If no related charging sessions are available and defaultToEnteredConsumption is true, the entered consumption is returned, otherwise 0 is returned.
    /// - Returns: The consumption as a Measurement<UnitEnergy>.
    private func consumption(useRelatedConsumptions: Bool) -> Measurement<UnitEnergy> {
        if useRelatedConsumptions {
            if let dataFromRelatedChargingSessions {
                return max(dataFromRelatedChargingSessions.consumption, .init(value: 0.0, unit: .kilowattHours)) // Ensure consumption is not negative
            } else {
                return defaultToEnteredConsumption ? max(consumption, .init(value: 0.0, unit: .kilowattHours)) : .init(value: 0.0, unit: .kilowattHours)
            }
        } else {
            return max(consumption, .init(value: 0.0, unit: .kilowattHours)) // Ensure consumption is not negative
        }
    }
    
    private func totalConsumption(
        useRelatedConsumptions: Bool,
        valueSource: ValueSource
    ) -> (home: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>) {
        switch consumptionType {
        case .total:
            let chargingConsumptionKWh = dataFromRelatedChargingSessions?.consumption.converted(to: .kilowattHours).value ?? 0.0
            var totalConsumptionKWh: Double
            switch valueSource {
            case .invoice:
                totalConsumptionKWh = contractualConsumptionKWh()
            case .calculated:
                totalConsumptionKWh = measuredConsumptionKWh() ?? 0.0
            case .automatic:
                totalConsumptionKWh = measuredConsumptionKWh() ?? contractualConsumptionKWh()
            }
            let homeConsumptionKWh = max(totalConsumptionKWh - chargingConsumptionKWh, 0.0) // Ensure home consumption is not negative
            return (home: .init(value: homeConsumptionKWh, unit: .kilowattHours), charging: .init(value: chargingConsumptionKWh, unit: .kilowattHours))
        case .home, .homeDiscount, .homeRefunded:
            var totalConsumptionKWh: Double
            switch valueSource {
            case .invoice:
                totalConsumptionKWh = consumption(useRelatedConsumptions: useRelatedConsumptions).converted(to: .kilowattHours).value
            case .calculated:
                totalConsumptionKWh = measuredConsumptionKWh() ?? 0.0
            case .automatic:
                totalConsumptionKWh = measuredConsumptionKWh() ?? consumption(useRelatedConsumptions: useRelatedConsumptions).converted(to: .kilowattHours).value
            }
            return (home: .init(value: totalConsumptionKWh, unit: .kilowattHours), charging: .init(value: 0.0, unit: .kilowattHours))
        case .charging, .chargingDiscount, .chargingRefunded, .refundingOtherPlan:
            var totalConsumptionKWh: Double
            switch valueSource {
            case .invoice:
                totalConsumptionKWh = consumption(useRelatedConsumptions: useRelatedConsumptions).converted(to: .kilowattHours).value
            case .calculated:
                totalConsumptionKWh = measuredConsumptionKWh() ?? 0.0
            case .automatic:
                totalConsumptionKWh = measuredConsumptionKWh() ?? consumption(useRelatedConsumptions: useRelatedConsumptions).converted(to: .kilowattHours).value
            }
            return (home: .init(value: 0.0, unit: .kilowattHours), charging: .init(value: totalConsumptionKWh, unit: .kilowattHours))
        }
    }
    
    func consumptionPerMonth(
        useRelatedConsumptions: Bool,
        reduceHomeBy: [String: Measurement<UnitEnergy>]?,
        valueSource: ValueSource
    ) -> [String: (home: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>)] {
        if valueSource == .invoice || (valueSource == .automatic && measuredConsumptionKWh() == nil) {
            let totalConsumption = totalConsumption(useRelatedConsumptions: useRelatedConsumptions, valueSource: valueSource)
            return distributeConsumption(totalConsumption, reduceHomeBy: reduceHomeBy)
        } else {
            // Sum up the consumptions for each month from the consumptionsKWh dictionary, considering the reduceTotalBy value.
            guard let consumptions else { return [:] }
            var monthlyConsumptions: [String: (home: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>)] = [:]
            for (date, consumptionKWh) in consumptions.consumptionsKWh {
                let monthKey = UserSettings.shared.groupingDateFormatter.string(from: date)
                
                // Get the reduced home consumption for this month if available
                let reduceHomeByKWh = reduceHomeBy?[monthKey]?.converted(to: .kilowattHours).value ?? 0.0
                
                let adjustedConsumptionKWh = max(consumptionKWh - reduceHomeByKWh, 0.0) // Ensure consumption is not negative
                if monthlyConsumptions[monthKey] != nil {
                    monthlyConsumptions[monthKey]!.home.value += adjustedConsumptionKWh
                } else {
                    monthlyConsumptions[monthKey] = (home: .init(value: adjustedConsumptionKWh, unit: .kilowattHours), charging: .init(value: 0.0, unit: .kilowattHours))
                }
            }
            return monthlyConsumptions
        }
    }
    
    private func distributeConsumption(
        _ totalConsumption: (home: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>),
        reduceHomeBy: [String: Measurement<UnitEnergy>]?
    ) -> [String: (home: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>)] {
        let numberOfDays = self.numberOfDays
        guard numberOfDays > 0 else {
            // If no days, return the total consumption as is for the validUntil month
            let monthKey = UserSettings.shared.groupingDateFormatter.string(from: validUntil)
            
            // Get the reduced home consumption for this month if available
            let reducedHomeConsumption = reduceHomeBy?[monthKey] ?? .init(value: 0.0, unit: .kilowattHours)
            let adjustedHomeConsumption = max(totalConsumption.home.value - reducedHomeConsumption.value, 0.0) // Ensure home consumption is not negative
            
            return [monthKey: (home: Measurement<UnitEnergy>(value: adjustedHomeConsumption, unit: .kilowattHours), charging: Measurement<UnitEnergy>(value: totalConsumption.charging.value, unit: .kilowattHours))]
        }
        
        let homeTotalKWh = totalConsumption.home.converted(to: .kilowattHours).value
        let chargingTotalKWh = totalConsumption.charging.converted(to: .kilowattHours).value
        
        // Determine the number of days for each of the covered months, calculate each month's cost portion, and store them in a dictionary
        var consumptionPerMonthKWh: [String: (home: Double, charging: Double)] = [:]
        for (monthKey, daysInMonth) in daysPerMonth {
            // Determine the share in this month
            let monthShare = Double(daysInMonth) / Double(numberOfDays)
            
            // Reduce the home consumption for this month if available
            let reducedHomeConsumption = reduceHomeBy?[monthKey] ?? .init(value: 0.0, unit: .kilowattHours)
            let adjustedHomeConsumption = max(homeTotalKWh * monthShare - reducedHomeConsumption.converted(to: .kilowattHours).value, 0.0) // Ensure home consumption is not negative
            
            consumptionPerMonthKWh[monthKey] = (home: adjustedHomeConsumption, charging: chargingTotalKWh * monthShare)
        }
        
        // Normalize the consumptions to ensure they sum up to the total consumption (to avoid rounding issues)
        let sumOfConsumptions = consumptionPerMonthKWh.values.reduce(0) { $0 + $1.home + $1.charging }
        
        // Get the total reduced home consumption across all months
        let totalReducedHomeConsumption = reduceHomeBy?.values.reduce(0.0) { $0 + $1.converted(to: .kilowattHours).value } ?? 0.0
        
        if sumOfConsumptions != homeTotalKWh + chargingTotalKWh - totalReducedHomeConsumption {
            let difference = (homeTotalKWh + chargingTotalKWh - totalReducedHomeConsumption) - sumOfConsumptions
            if let firstKey = consumptionPerMonthKWh.keys.first {
                let homeShare = homeTotalKWh / (homeTotalKWh + chargingTotalKWh - totalReducedHomeConsumption)
                consumptionPerMonthKWh[firstKey]!.home += difference * homeShare
                consumptionPerMonthKWh[firstKey]!.charging += difference * (1 - homeShare)
            }
        }
        
        // Convert the consumptions to Measurement type
        var consumptionPerMonthWithUnit: [String: (home: Measurement<UnitEnergy>, charging: Measurement<UnitEnergy>)] = [:]
        for (monthKey, consumption) in consumptionPerMonthKWh {
            consumptionPerMonthWithUnit[monthKey] = (home: Measurement<UnitEnergy>(value: consumption.home, unit: .kilowattHours), charging: Measurement<UnitEnergy>(value: consumption.charging, unit: .kilowattHours))
        }
        return consumptionPerMonthWithUnit
    }
    
    /// Calculates the total cost for the home consumption over its entire duration, adding up all price elements.
    /// - Parameter includingVAT: Indicates whether to calculate cost without VAT or with VAT. Default is true (including VAT).
    /// - Parameter useRelatedConsumptions: If true, the consumption from related charging sessions is used instead of the entered consumption. If no charging sessions are availale, the entered consumption is used.
    /// - Returns: The total cost as Cost.
    private func cost(
        includingVAT: Bool = true,
        useRelatedConsumptions: Bool,
        reduceTotalBy: [String: Cost],
        valueSource: ValueSource,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) -> Cost {
        guard let priceElements else {
            return .init(amount: 0.0)
        }
        
        let value = priceElements.reduce(0.0) {
            switch $1.type {
            case .daily:
                return $0 + ($1.getConvertedCost(valueSource: valueSource, includingVAT: includingVAT, startTime: startTime, endTime: endTime).amount * Double(numberOfDays))
            case .once:
                return $0 + $1.getConvertedCost(valueSource: valueSource, includingVAT: includingVAT, startTime: startTime, endTime: endTime).amount
            case .byConsumption(let energyUnitSymbol):
                guard let energyUnit = UserSettings.shared.energyUnit(for: energyUnitSymbol) else {
                    fatalError("Unknown energy unit symbol: \(energyUnitSymbol)")
                }
                let consumption = consumption(useRelatedConsumptions: useRelatedConsumptions).converted(to: energyUnit).value
                return $0 + ($1.getConvertedCost(valueSource: valueSource, includingVAT: includingVAT, startTime: startTime, endTime: endTime).amount * consumption)
            }
        }
        
        // Add up all costs from reduceTotalBy dictionary
        let totalReduction = reduceTotalBy.values.reduce(0.0) { $0 + ($1.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0) }
        
        return .init(amount: value + totalReduction) // totalReduction is added as it's a negative value, so we need to add it to subtract if from the total cost
    }
    
    func totalCost(
        includingVAT: Bool = true,
        useRelatedConsumptions: Bool,
        reduceTotalBy: [String: Cost]?,
        valueSource: ValueSource
    ) -> (home: Cost, charging: Cost) {
        let reduceTotalBy = reduceTotalBy ?? [:]
        switch consumptionType {
        case .total:
            let totalCost = cost(includingVAT: includingVAT, useRelatedConsumptions: false, reduceTotalBy: reduceTotalBy, valueSource: valueSource).converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0
            guard totalCost > 0 else {
                // If no total cost, there can't be any monthly cost
                return (home: .init(amount: 0.0), charging: .init(amount: 0.0))
            }
            
            let totalConsumption = totalConsumption(useRelatedConsumptions: useRelatedConsumptions, valueSource: valueSource)
            let fullConsumptionKWh = totalConsumption.home.converted(to: .kilowattHours).value + totalConsumption.charging.converted(to: .kilowattHours).value
            guard fullConsumptionKWh > 0 else {
                // If no consumption, there can't be any related charging cost
                return (home: .init(amount: totalCost), charging: .init(amount: 0.0))
            }
            
            let homeShare = totalConsumption.home.value / fullConsumptionKWh
            return (home: .init(amount: totalCost * homeShare), charging: .init(amount: totalCost * (1 - homeShare)))
        case .home, .homeDiscount, .homeRefunded:
            // These are home consumptions, so no charging costs should be included
            let totalCost = cost(includingVAT: includingVAT, useRelatedConsumptions: useRelatedConsumptions, reduceTotalBy: reduceTotalBy, valueSource: valueSource)
            return (home: totalCost, charging: .init(amount: 0.0))
        case .charging, .chargingDiscount, .chargingRefunded, .refundingOtherPlan:
            // These are charging consumptions, so the full cost should be included as charging cost
            let totalCost = cost(includingVAT: includingVAT, useRelatedConsumptions: useRelatedConsumptions, reduceTotalBy: reduceTotalBy, valueSource: valueSource)
            return (home: .init(amount: 0.0), charging: totalCost)
        }
    }
    
    func costPerMonth(
        includingVAT: Bool = true,
        useRelatedConsumptions: Bool,
        reduceTotalBy: [String: Cost]?,
        valueSource: ValueSource
    ) -> [String: (home: Cost, charging: Cost)] {
        let totalCost = totalCost(includingVAT: includingVAT, useRelatedConsumptions: useRelatedConsumptions, reduceTotalBy: reduceTotalBy, valueSource: valueSource)
        return distributeCost(totalCost)
    }
    
    private func distributeCost(_ totalCost: (home: Cost, charging: Cost)) -> [String: (home: Cost, charging: Cost)] {
        let numberOfDays = self.numberOfDays
        guard numberOfDays > 0 else {
            // If no days, return the total cost as is for the validUntil month
            let monthKey = UserSettings.shared.groupingDateFormatter.string(from: validUntil)
            return [monthKey: totalCost]
        }
        
        // Determine the number of days for each of the covered months, calculate each month's cost portion, and store them in a dictionary
        var costPerMonth: [String: (home: Double, charging: Double)] = [:]
        for (monthKey, daysInMonth) in daysPerMonth {
            // Determine the cost portion in this month
            let monthShare = Double(daysInMonth) / Double(numberOfDays)
            costPerMonth[monthKey] = (
                home: (totalCost.home.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0) * monthShare,
                charging: (totalCost.charging.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0) * monthShare
            )
        }
        
        // Normalize the costs to ensure they sum up to the total cost (to avoid rounding issues)
        let sumOfCosts = costPerMonth.values.reduce(0) { $0 + $1.home + $1.charging }
        let totalCostAmount = (totalCost.home.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0) + (totalCost.charging.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0)
        if sumOfCosts != totalCostAmount {
            let difference = totalCostAmount - sumOfCosts
            if let firstKey = costPerMonth.keys.first {
                let homeShare = (totalCost.home.converted(to: UserSettings.shared.currencyIdentifier)?.amount ?? 0.0) / totalCostAmount
                costPerMonth[firstKey]!.home += difference * homeShare
                costPerMonth[firstKey]!.charging += difference * (1 - homeShare)
            }
        }
        
        // Convert the costs to Cost type
        var costPerMonthWithCostType: [String: (home: Cost, charging: Cost)] = [:]
        for (monthKey, costs) in costPerMonth {
            costPerMonthWithCostType[monthKey] = (home: .init(amount: costs.home), charging: .init(amount: costs.charging))
        }
        return costPerMonthWithCostType
    }
    
    func possibleChargingSessions(ignoreConsumptionType: Bool, modelContext: ModelContext, showRefundedSessions: Bool) -> [ChargingSession]? {
        if let chargingSessions = try? modelContext.fetch(FetchDescriptor<ChargingSession>(
            predicate: #Predicate { session in
                validFrom <= session.endTime && session.endTime <= validUntil
            }
        )) {
            if chargingSessions.isEmpty {
                return nil
            } else {
                // Match the possible plan types
                var planType: ChargingCostPlan.PlanType? = nil
                if !ignoreConsumptionType {
                    if showRefundedSessions {
                        planType = .refunded
                    } else {
                        switch consumptionType {
                        case .refundingOtherPlan:
                            planType = .refunded
                        case .chargingDiscount:
                            planType = .homeDiscounted
                        case .charging:
                            planType = .homeConsumption
                        default:
                            planType = nil
                        }
                    }
                }
                
                var candidates = [ChargingSession]()
                if let planType {
                    candidates = chargingSessions.filter({ session in
                        session.chargingCostPlan?.planType == planType &&
                        (consumptionType == .chargingRefunded ? session.chargingCostPlan?.includedInOtherPlan?.charger?.location?.id == self.associatedLocation?.id : session.chargingCostPlan?.charger?.location?.id == self.associatedLocation?.id)
                    })
                } else {
                    // We return all sessions for the location
                    candidates = chargingSessions.filter({ session in
                        (consumptionType == .chargingRefunded ? session.chargingCostPlan?.includedInOtherPlan?.charger?.location?.id == self.associatedLocation?.id : session.chargingCostPlan?.charger?.location?.id == self.associatedLocation?.id)
                    })
                }
                return candidates.sorted(by: { $0.endTime < $1.endTime })
            }
        } else {
            return nil
        }
    }
    
    /// Simulates the cost of home consumption for a given time range and consumption and a given price per kWh. Only price elements not excluded from simulation are used. ValueType for the simulation is always .calculated.
    /// - Parameters:
    ///   - consumptionKWh: The consumption in kWh to simulate the cost for. This allows to simulate the cost for different consumption values than the one entered in the home consumption, e.g. for a future month or to see how the cost would have changed with a different consumption.
    ///   - pricePerKWh: The price per kWh to use for the consumption.
    ///   - start: The start date of the simulation period.
    ///   - end: The end date of the simulation period.
    /// - Returns: The simulated cost for the given consumption and time range.
    func simulateCost(of consumptionKWh: Double, with pricePerKWh: Cost, startTime: Date, endTime: Date) -> Cost {
        // Calculate the proportion of the time range (start to end) within the validFrom to validUntil range
        let duration: Double = endTime.timeIntervalSince(startTime) / 60
        let totalDuration = validUntil.timeIntervalSince(validFrom)
        guard totalDuration > 0 else {
            return .init(amount: 0.0)
        }
        let proportion = duration / totalDuration
        
        // Filter the price elements to be included in the simulation
        guard let priceElements else {
            return .init(amount: 0.0)
        }
        let includedPriceElements = priceElements.filter { $0.excludeFromSimulation == false }
        
        // Filter the included price elements by those with types .once and .daily
        let sumOfPriceElementsOnce = sumOfPriceElements(includedPriceElements.filter {
            if case .once = $0.type { return true } else { return false }
        }, valueSource: .calculated, startTime: startTime, endTime: endTime)
        let sumOfPriceElementsDaily = sumOfPriceElements(includedPriceElements.filter {
            if case .daily = $0.type { return true } else { return false }
        }, valueSource: .calculated, startTime: startTime, endTime: endTime)
        
        // Calculate the fixed costs (once + daily * number of days)
        let fixedCosts = sumOfPriceElementsOnce.amount + sumOfPriceElementsDaily.amount * Double(numberOfDays)
        
        // Calculate the variable cost
        let sumOfPriceElementsSpecific = sumOfPriceElements(includedPriceElements.filter {
            if case .byConsumption(_) = $0.type { return true } else { return false }
        }, valueSource: .calculated, startTime: startTime, endTime: endTime)
        
        // Add the given price per kWh
        let sumOfPriceElementsByConsumption = sumOfPriceElementsSpecific + pricePerKWh
        
        // Calculate simulated cost
        let simulatedCost = fixedCosts * proportion + sumOfPriceElementsByConsumption.amount * consumptionKWh
        return .init(amount: simulatedCost)
    }
    
    /// Calculates the cost per kWh for the home consumption over a given time range and resolution. This function uses the associated PowerPrices to calculate the cost per kWh for each time interval within the specified range.
    /// - Parameters:
    ///   - startTime: The start date of the time range for which to calculate the cost per kWh.
    ///   - endTime: The end date of the time range for which to calculate the cost per kWh.
    ///   - resolutionMinutes: The resolution in minutes for which to calculate the cost per kWh.
    /// - Returns: A dictionary mapping each date to a tuple containing the fixed and variable costs.
    func costPerKWh(startTime: Date, endTime: Date, resolutionMinutes: Int) async throws -> [Date: (fixed: [String: Cost], variable: [String: Cost])] {
        guard let prices else {
            return [:]
        }
        return try await prices.costPerKWh(
            for: self,
            startTime: startTime,
            endTime: endTime,
            resolutionMinutes: resolutionMinutes
        )
    }
    
    func sumOfPriceElementsByConsumption(valueSource: ValueSource, startTime: Date? = nil, endTime: Date? = nil) -> Cost {
        if let priceElements {
            let specificPriceElements = priceElements.filter {
                if case .byConsumption(_) = $0.type { return true } else { return false }
            }
            return sumOfPriceElements(specificPriceElements, valueSource: valueSource, startTime: startTime, endTime: endTime)
        }
        return .init(amount: 0.0)
    }
    
    func sumOfPriceElementsDaily(valueSource: ValueSource, startTime: Date? = nil, endTime: Date? = nil) -> Cost {
        if let priceElements {
            let specificPriceElements = priceElements.filter {
                if case .daily = $0.type { return true } else { return false }
            }
            return sumOfPriceElements(specificPriceElements, valueSource: valueSource, startTime: startTime, endTime: endTime)
        }
        return .init(amount: 0.0)
    }
    
    func sumOfPriceElementsOnce(valueSource: ValueSource, startTime: Date? = nil, endTime: Date? = nil) -> Cost {
        if let priceElements {
            let specificPriceElements = priceElements.filter {
                if case .once = $0.type { return true } else { return false }
            }
            return sumOfPriceElements(specificPriceElements, valueSource: valueSource, startTime: startTime, endTime: endTime)
        }
        return .init(amount: 0.0)
    }
    
    private func sumOfPriceElements(_ priceElements: [PriceElement], valueSource: ValueSource, startTime: Date? = nil, endTime: Date? = nil) -> Cost {
        return .init(
            amount: priceElements.reduce(0.0) { $0 + $1.getConvertedCost(valueSource: valueSource, includingVAT: UserSettings.shared.displayGrossPrices, startTime: startTime, endTime: endTime).amount }
        )
    }
    
    static func < (lhs: HomeConsumption, rhs: HomeConsumption) -> Bool {
        lhs.validUntil < rhs.validUntil
    }
}

