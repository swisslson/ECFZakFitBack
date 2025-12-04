//
//  StringDate.swift
//  ecfZakFit
//
//  Created by cyrilH on 29/11/2025.
//
import Vapor

extension String {
    func toDate() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone.current
        return formatter.date(from: self)
    }
}

extension Date {
    func toString(format: String = "yyyy-MM-dd") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}


extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps)!
    }
    
    func endOfWeek(for date: Date) -> Date {
        let start = startOfWeek(for: date)
        return self.date(byAdding: .day, value: 7, to: start)!.addingTimeInterval(-1)
    }
    
    func endOfDay(for date: Date) -> Date {
        return self.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay(for: date))!
    }
    
    func endOfMonth(for date: Date) -> Date {
        let start = self.date(from: dateComponents([.year, .month], from: date))!
        return self.date(byAdding: DateComponents(month: 1, second: -1), to: start)!
    }
}
