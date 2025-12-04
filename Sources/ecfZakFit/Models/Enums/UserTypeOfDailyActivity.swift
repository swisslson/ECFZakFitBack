//
//  TypeDactiviterJournaliere.swift
//  ecfZakFit
//
//  Created by cyrilH on 25/11/2025.
//

import Fluent

enum UserTypeDactiviterJournaliere: String, Codable, CaseIterable, Sendable {
    case sedentaire
    case deuxFoisSemaine
    case troisAQuatreFoisSemaine
    case quotidien
    case intensif
}
