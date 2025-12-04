//
//  TypeDactiviterJournaliere.swift
//  ecfZakFit
//
//  Created by cyrilH on 25/11/2025.
//

import Fluent

enum UserTypeOfDailyActivity: String, Codable, CaseIterable, Sendable {
    case sedentary
    case twiceaweek
    case threeFourTimesAWeek
    case daily
    case intensive
}
