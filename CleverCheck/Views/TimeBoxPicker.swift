//
//  TimePeriodPicker.swift
//  CleverCheck
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
                
                Text(timeBox.formattedTime)
                
                if canBeRemoved {
                    Button(action: {
                        timeBox.selectedResolution = .none
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
                
                Picker("Month", selection: $timeBox.selectedDate) {
                    ForEach(timeBox.monthPickerList, id: \.self) { date in
                        Text(DateFormatter.displayAbbreviatedMonthOnly.string(from: date)).tag(date)
                    }
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
                        timeBox.selectedResolution = .none
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
                        timeBox.selectedResolution = .none
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
                
                Text("All time")
                
                Button(action: {
                    if timeBox.allowedResolutions.contains(.yearly) {
                        timeBox.selectedResolution = .yearly
                    } else if timeBox.allowedResolutions.contains(.monthly) {
                        timeBox.selectedResolution = .monthly
                    } else if timeBox.allowedResolutions.contains(.daily) {
                        timeBox.selectedResolution = .daily
                    }
                }) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.link)
                }
                .buttonStyle(.plain)
                
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
    }
    
    func decreaseDay() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        }
    }
    
    func increaseDay() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
        }
    }
    
    func decreaseMonth() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate)!
        }
    }
    
    func increaseMonth() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate)!
        }
    }
    
    func decreaseYear() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .year, value: -1, to: selectedDate)!
        }
    }
    
    func increaseYear() {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .year, value: 1, to: selectedDate)!
        }
    }
    
    func switchToYearly() {
        if allowedResolutions.contains(.yearly) {
            // Set correct date - we always need first of January of the year
            let year = Calendar.current.component(.year, from: selectedDate)
            let firstDayOfYear = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!
            self.selectedDate = firstDayOfYear
            withAnimation {
                self.selectedResolution = .yearly
            }
        }
    }
    
    func switchToMonthly() {
        if allowedResolutions.contains(.monthly) {
            // Set correct date - we always need the first day of the month
            let year = Calendar.current.component(.year, from: selectedDate)
            let month = Calendar.current.component(.month, from: selectedDate)
            let firstDayOfMonth = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
            self.selectedDate = firstDayOfMonth
            withAnimation {
                self.selectedResolution = .monthly
            }
        }
    }
    
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
}
