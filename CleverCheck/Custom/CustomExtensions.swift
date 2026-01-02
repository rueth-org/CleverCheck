//
//  CustomExtensions.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 01/12/2025.
//

import Foundation

extension Date {
    var startDateOfYear: Date {
        guard let date = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: self)) else {
            fatalError("Unable to get start date from date")
        }
        return date
    }
    
    var startDateOfMonth: Date {
        guard let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) else {
            fatalError("Unable to get start date from date")
        }
        return date
    }

    var endDateOfMonth: Date {
        guard let date = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: self.startDateOfMonth) else {
            fatalError("Unable to get end date from date")
        }
        return date
    }
}
