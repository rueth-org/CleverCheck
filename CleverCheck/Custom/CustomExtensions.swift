//
//  CustomExtensions.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 01/12/2025.
//

import Foundation

extension Date {
    /// Returns the start date of the year for the given date
    var startOfYear: Date {
        guard let date = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: self)) else {
            fatalError("Unable to get start date from date")
        }
        return date
    }
    
    /// Returns the end date of the year for the given date, i.e., the first day of the next year minus one second
    var endOfYear: Date {
        guard let date = Calendar.current.date(byAdding: DateComponents(year: 1), to: self.startOfYear)?.addingTimeInterval(-1) else {
            fatalError("Unable to get end date from date")
        }
        return date
    }

    /// Returns the start date of the month for the given date
    var startOfMonth: Date {
        guard let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) else {
            fatalError("Unable to get start date from date")
        }
        return date
    }

    /// Returns the end date of the month for the given date, i.e., the first day of the next month minus one second
    var endOfMonth: Date {
        guard let date = Calendar.current.date(byAdding: DateComponents(month: 1), to: self.startOfMonth)?.addingTimeInterval(-1) else {
            fatalError("Unable to get end date from date")
        }
        return date
    }
    
    /// Returns the start date of the day for the given date
    var startOfDay: Date {
        guard let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: self)) else {
            fatalError("Unable to get start date from date")
        }
        return date
    }
    
    /// Returns the end date of the day for the given date, i.e., the first day of the next day minus one second
    var endOfDay: Date {
        guard let date = Calendar.current.date(byAdding: .day, value: 1, to: self.startOfDay)?.addingTimeInterval(-1) else {
            fatalError("Unable to get end date from date")
        }
        return date
    }
}

extension DateFormatter {
    var year: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }
    
    var shortMonthYear: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yy"
        return formatter
    }
    
    var longMonthYear: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    var shortDayMonthYear: DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dd.MM.yy")
        return formatter
    }
    
    var longDayMonthYear: DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d. MMM yyyy")
        return formatter
    }
    
    /// Returns the localized date format string for a short time style (equivalent to `.timeStyle = .short`).
    /// Falls back to a reasonable template if the formatter's `dateFormat` is unavailable.
    static func localizedShortTimeFormat(locale: Locale = .current) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeStyle = .short
        f.dateStyle = .none
        if let df = f.dateFormat, !df.isEmpty {
            return df
        }
        // As a fallback, produce a localized format from a template using hour/minute
        return DateFormatter.dateFormat(fromTemplate: "j:mm", options: 0, locale: locale) ?? "HH:mm"
    }
    
    // For a chart showing one day, only the time is displayed in a shortened localized format
    // The localized time-only formatter equivalent to `.formatted(date: .omitted, time: .shortened)`
    static let chartDisplayDateDaily: DateFormatter = {
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale.current
            f.timeStyle = .short
            f.dateStyle = .none
            return f
        }()
        return timeFormatter
    }()
    
    // For a chart showing one month, only the days are displayed as two-digit number
    static let chartDisplayDateMonthly: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "dd"
         return formatter
    }()
    
    // For a chart showing one year, only the months are displayed as two-digit number
    static let chartDisplayDateYearly: DateFormatter = {
         let formatter = DateFormatter()
         formatter.dateFormat = "MM"
         return formatter
    }()
    
    static let displayAbbreviatedMonthOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()
}
