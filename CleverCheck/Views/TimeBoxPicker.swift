//
//  TimePeriodPicker.swift
//  CleverCheck
//
//  newDate logic see /Users/ulrich/Documents/Entwicklung/CleverCheck
//
//  Created by Ulrich Rüth on 07/01/2026.
//

import SwiftUI

struct TimeBoxPicker: View {
    @Bindable var timeBox: TimeBox
    var canBeRemoved: Bool = true
    
    var body: some View {
        switch timeBox.selectedResolution {
        case .yearly:
            HStack(alignment: .center) {
                Button(action: timeBox.decreaseYear) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if timeBox.allowedResolutions.contains(.monthly) || timeBox.allowedResolutions.contains(.daily) {
                    Button(action: {
                        if timeBox.allowedResolutions.contains(.monthly) {
                            timeBox.switchToMonthly()
                        } else {
                            timeBox.switchToDaily()
                        }
                    }) {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(.link)
                    }
                    .buttonStyle(.plain)
                }
                
                Text(timeBox.formattedTime)
                
                if canBeRemoved {
                    Button(action: {
                        timeBox.switchToNone()
                    }) {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.link)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: timeBox.increaseYear) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
        case .monthly:
            HStack(alignment: .center) {
                Button(action: timeBox.decreaseMonth) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if timeBox.allowedResolutions.contains(.daily) {
                    Button(action: {
                        timeBox.switchToDaily()
                    }) {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(.link)
                    }
                    .buttonStyle(.plain)
                }
                
                Picker("Month", selection: $timeBox.selectedDate) {
                    ForEach(timeBox.monthPickerList, id: \.self) { date in
                        Text(DateFormatter.displayAbbreviatedMonthOnly.string(from: date)).tag(date)
                    }
                }
                .onChange(of: timeBox.selectedDate) {
                    // Only the month has changed, so take year and day from lastDate
                    let year = timeBox.lastDate.year ?? Calendar.current.component(.year, from: timeBox.selectedDate)
                    let month = Calendar.current.component(.month, from: timeBox.selectedDate)
                    let day = TimeBox.getCorrectDay(
                        day: timeBox.lastDate.day ?? Calendar.current.component(.day, from: timeBox.selectedDate),
                        month: month,
                        year: year
                    )
                    timeBox.lastDate = DateComponents(year: year, month: month, day: day)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                
                if timeBox.allowedResolutions.contains(.yearly) {
                    Button(action: timeBox.switchToYearly) {
                        Text(verbatim: "\(Calendar.current.component(.year, from: timeBox.selectedDate))")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(verbatim: "\(Calendar.current.component(.year, from: timeBox.selectedDate))")
                        .foregroundStyle(Color.primary)
                }
                
                if canBeRemoved {
                    Button(action: {
                        timeBox.switchToNone()
                    }) {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.link)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: timeBox.increaseMonth) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
        case .daily:
            HStack(alignment: .center) {
                Button(action: timeBox.decreaseDay) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Picker("Day", selection: $timeBox.selectedDate) {
                    ForEach(timeBox.dayPickerList, id: \.self) { date in
                        Text(DateFormatter.chartDisplayDateMonthly.string(from: date)).tag(date)
                    }
                }
                .onChange(of: timeBox.selectedDate) {
                    // Only the day has changed, so take year and month from oldDate
                    let year = timeBox.lastDate.year ?? Calendar.current.component(.year, from: timeBox.selectedDate)
                    let month = timeBox.lastDate.month ?? Calendar.current.component(.month, from: timeBox.selectedDate)
                    let day = Calendar.current.component(.day, from: timeBox.selectedDate)
                    timeBox.lastDate = DateComponents(year: year, month: month, day: day)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                
                if timeBox.allowedResolutions.contains(.monthly) {
                    Button(action: timeBox.switchToMonthly) {
                        Text(DateFormatter.displayAbbreviatedMonthOnly.string(from: timeBox.selectedDate))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(DateFormatter.displayAbbreviatedMonthOnly.string(from: timeBox.selectedDate))
                        .foregroundStyle(Color.primary)
                }
                
                if timeBox.allowedResolutions.contains(.yearly) {
                    Button(action: timeBox.switchToYearly) {
                        Text(verbatim: "\(Calendar.current.component(.year, from: timeBox.selectedDate))")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(verbatim: "\(Calendar.current.component(.year, from: timeBox.selectedDate))")
                        .foregroundStyle(Color.primary)
                }
                
                if canBeRemoved {
                    Button(action: {
                        timeBox.switchToNone()
                    }) {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.link)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: timeBox.increaseDay) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
        case .none:
            HStack(alignment: .center) {
                Spacer()
                
                Button(action: {
                    if timeBox.allowedResolutions.contains(.yearly) {
                        timeBox.switchToYearly()
                    } else if timeBox.allowedResolutions.contains(.monthly) {
                        timeBox.switchToMonthly()
                    } else if timeBox.allowedResolutions.contains(.daily) {
                        timeBox.switchToDaily()
                    }
                }) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(.link)
                }
                .buttonStyle(.plain)
                
                Text("All time")
                
                Spacer()
            }
        }
    }
}

@Observable
class TimeBox {
    enum Resolution {
        case yearly
        case monthly
        case daily
        case none
    }
    
    var selectedDate: Date
    var selectedResolution: Resolution
    @ObservationIgnored var allowedResolutions: [Resolution]
    var selectIndividualItem: (_ date: Date) -> ()
    @ObservationIgnored var lastDate: DateComponents
    
    var referenceDate: Date {
        var date = selectedDate
        let calendar = Calendar.current
        if selectedResolution == .yearly {
            let year = calendar.component(.year, from: selectedDate)
            date = DateComponents(calendar: calendar, year: year, month: 1, day: 1).date!
        } else if selectedResolution == .monthly {
            let year = calendar.component(.year, from: selectedDate)
            let month = calendar.component(.month, from: selectedDate)
            date = DateComponents(calendar: calendar, year: year, month: month, day: 1).date!
        } else if selectedResolution == .daily {
            let year = calendar.component(.year, from: selectedDate)
            let month = calendar.component(.month, from: selectedDate)
            let day = calendar.component(.day, from: selectedDate)
            date = DateComponents(calendar: calendar, year: year, month: month, day: day).date!
        }
        return date
    }
    
    var monthPickerList: [Date] {
        var result = [Date]()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        for i in 0..<12 {
            let month = i + 1
            result.append(DateComponents(calendar: calendar, year: year, month: month, day: 1).date!)
        }
        return result
    }
    
    var dayPickerList: [Date] {
        var result = [Date]()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date(timeInterval: 0, since: selectedDate))!.count
        for i in 0..<daysInMonth {
            let day = i + 1
            let dateTag = DateComponents(calendar: calendar, year: year, month: month, day: day).date!
            result.append(dateTag)
        }
        return result
    }
    
    var timePeriod: (start: Date, end: Date)? {
        switch selectedResolution {
        case .daily: return (selectedDate.startOfDay, selectedDate.endOfDay)
        case .monthly: return (selectedDate.startOfMonth, selectedDate.endOfMonth)
        case .yearly: return (selectedDate.startOfYear, selectedDate.endOfYear)
        case .none: return nil
        }
    }
    
    var formattedTime: String {
        switch selectedResolution {
        case .daily: return DateFormatter().longDayMonthYear.string(from: selectedDate)
        case .monthly: return DateFormatter().longMonthYear.string(from: selectedDate)
        case .yearly: return DateFormatter().year.string(from: selectedDate)
        case .none: return ""
        }
    }
    
    init(
        selectedDate: Date,
        selectedResolution: Resolution,
        allowedResolutions: [Resolution],
        selectIndividualItem: @escaping (_: Date) -> ()
    ) {
        self.selectedDate = selectedDate
        self.selectedResolution = selectedResolution
        self.allowedResolutions = allowedResolutions
        self.selectIndividualItem = selectIndividualItem
        self.lastDate = TimeBox.setLastDate(from: selectedDate)
    }
    
    func increaseDay() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
        }
        lastDate = TimeBox.setLastDate(from: selectedDate)
    }
    
    func decreaseDay() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        }
        lastDate = TimeBox.setLastDate(from: selectedDate)
    }
    
    func increaseMonth() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate)!
        }
        lastDate = TimeBox.setLastDate(from: selectedDate)
    }
    
    func decreaseMonth() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate)!
        }
        lastDate = TimeBox.setLastDate(from: selectedDate)
    }
    
    func increaseYear() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .year, value: 1, to: selectedDate)!
        }
        lastDate = TimeBox.setLastDate(from: selectedDate)
    }
    
    func decreaseYear() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .year, value: -1, to: selectedDate)!
        }
        lastDate = TimeBox.setLastDate(from: selectedDate)
    }
    
    /// Switches the resolution to yearly, coming from none. The lastDate is unchanged.
    /// The selectedDate needs to be the 1st of January of the selected year.
    /// The new selectedDate is set to:
    /// - the year of the lastDate
    /// - the month of the lastDate
    /// - the minimum of the day of the lastDate or the number of days of the new month
    func switchToYearly() {
        if allowedResolutions.contains(.yearly) {
            // Set correct date - we always need first of January of the year
            let year = lastDate.year
            let firstDayOfYear = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!
            self.selectedDate = firstDayOfYear
            withAnimation {
                self.selectedResolution = .yearly
            }
        }
    }
    
    /// Switches the resolution to monthly, coming either from yearly or none. The lastDate is unchanged.
    /// The selectedDate needs to be the 1st day of the selected month.
    /// The new selectedDate is set to:
    /// - the year of the lastDate
    /// - the month of the lastDate
    /// - day: 1
    func switchToMonthly() {
        if allowedResolutions.contains(.monthly) {
            // Set correct date - we always need the first day of the month
            let year = lastDate.year
            let month = lastDate.month
            let firstDayOfMonth = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
            self.selectedDate = firstDayOfMonth
            withAnimation {
                self.selectedResolution = .monthly
            }
        }
    }
    
    /// Switches the resolution to daily, coming from yearly, monthly or noe. The selectedDate is the current lastDate, which is left unchanged.
    func switchToDaily() {
        if allowedResolutions.contains(.daily) {
            selectedDate = Calendar.current.date(from: lastDate)!
            withAnimation {
                self.selectedResolution = .daily
            }
        }
    }
    
    func switchToNone() {
        withAnimation {
            self.selectedResolution = .none
        }
    }
    
    /// Switches the resolution to the next finer resolution based on the passed dateKey.
    /// To switch from yearly to monthly, the dateKey needs to be parsable as month (1 to 12). The newDate is set to:
    /// - the year as previously
    /// - the month as parsed
    /// - the minimum of the day of the lastDate or the number of days of the new month
    /// To switch from monthly to daily, the dateKey needs to be parsable as day (1 to 31). The newDate is set to:
    /// - the year as previously
    /// - the month as previously
    /// - the day as parsed
    /// From daily, the function tries to switch to an individual item by using the function selectIndividualItem.
    /// - Parameter dateKey: The date key as described above.
    func switchResolution(_ dateKey: String) {
        var switched = false
        let calendar = Calendar.current
        var newDate: Date? = nil
        switch selectedResolution {
        case .yearly:
            // Switch to the month tapped and stored in dateKey as String (double-digit integer)
            let year = calendar.component(.year, from: selectedDate)
            let month = Int(dateKey) ?? calendar.component(.month, from: Date.now)
            newDate = DateComponents(
                calendar: calendar,
                year: year,
                month: month,
                day: 1
            ).date
            if allowedResolutions.contains(.monthly), let newDate {
                switched = true
                
                // Set lastDate
                let day = TimeBox.getCorrectDay(day: lastDate.day ?? 1, month: month, year: year)
                lastDate = DateComponents(year: year, month: month, day: day)
                
                withAnimation {
                    selectedDate = newDate
                    selectedResolution = .monthly
                }
            }
        case .monthly:
            // TODO this produces a runtime error: Picker: the selection "2025-12-17 23:00:00 +0000" is invalid and does not have an associated tag, this will give undefined results.
            // Switch to the day tapped and stored in dateKey as String (double-digit integer)
            let year = calendar.component(.year, from: selectedDate)
            let month = calendar.component(.month, from: selectedDate)
            let day = Int(dateKey) ?? calendar.component(.day, from: Date.now)
            newDate = DateComponents(
                calendar: calendar,
                year: year,
                month: month,
                day: day
            ).date
            if allowedResolutions.contains(.daily), let newDate {
                switched = true
                
                // Set lastDate
                lastDate = DateComponents(year: year, month: month, day: day)
                
                withAnimation {
                    selectedDate = newDate
                    selectedResolution = .daily
                }
            }
        case .daily:
            if let time = DateFormatter.chartDisplayDateDaily.date(from: dateKey) {
                let year = calendar.component(.year, from: selectedDate)
                let month = calendar.component(.month, from: selectedDate)
                let day = calendar.component(.day, from: selectedDate)
                
                // Add year, month and day to the time
                newDate = DateComponents(
                    calendar: calendar,
                    year: year,
                    month: month,
                    day: day,
                    hour: calendar.component(.hour, from: time),
                    minute: calendar.component(.minute, from: time)
                ).date
                
                if let newDate {
                    switched = true
                    selectIndividualItem(newDate)
                }
            }
        case .none: break
        }
        
        if !switched, let newDate {
            // If no switch yet, go for individual item
            selectIndividualItem(newDate)
        }
    }
    
    func getKeyForDate(_ date: Date) -> String {
        switch selectedResolution {
        case .yearly: return DateFormatter.chartDisplayDateYearly.string(from: date)
        case .monthly: return DateFormatter.chartDisplayDateMonthly.string(from: date)
        case .daily: return DateFormatter.chartDisplayDateDaily.string(from: date)
        case .none: return ""
        }
    }
    
    private static func setLastDate(from selectedDate: Date) -> DateComponents {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        let day = calendar.component(.day, from: selectedDate)
        return DateComponents(
            calendar: calendar,
            year: year,
            month: month,
            day: day
        )
    }
    
    /// Gets the correct day for the given month of the given year.
    /// The correct day is either the given day or, if it doesn't exist, the last day of the given month.
    /// Examples:
    /// - At a given day=31, month=2, year=2026, the returned day would be 28.
    /// - At a given day=15, month=2, year=2026, the returned day would be 15.
    /// - Parameters:
    ///   - day: The day to be considered or corrected to the last day of the given month.
    ///   - month: The given month.
    ///   - year: The given year.
    /// - Returns: The corrected day.
    static func getCorrectDay(day: Int, month: Int, year: Int) -> Int {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month)
        let date = calendar.date(from: dateComponents)!
        let range = calendar.range(of: .day, in: .month, for: date)!
        let numDays = range.count
        return min(numDays, day)
    }
}
