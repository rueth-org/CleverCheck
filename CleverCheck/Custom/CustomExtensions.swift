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
        guard let date = Calendar.current.date(byAdding: DateComponents(year: 1, day: -1), to: self.startOfYear)?.addingTimeInterval(-1) else {
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
        guard let date = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: self.startOfMonth)?.addingTimeInterval(-1) else {
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
}
