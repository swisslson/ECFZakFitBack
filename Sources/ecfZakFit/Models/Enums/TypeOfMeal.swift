//
//  TypeOfMeal.swift
//  ecfZakFit
//
//  Created by cyrilH on 25/11/2025.
//
import Fluent

enum TypeOfMeal: String, Codable, CaseIterable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
}
