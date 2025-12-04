//
//  TypeOfActivityDTO.swift
//  ecfZakFit
//
//  Created by cyrilH on 28/11/2025.
//

import Vapor

// MARK: - Type of Activity DTOs

/// DTO pour la création d'un nouveau type d'activité
/// Utilisé dans la requête POST /types-activity
struct CreateTypeOfActivityDTO: Content {
    /// Le nom de l'activité (cardio, bodybuilding, yoga)
    var nameOfActivity: NameOfActivity
}

/// DTO pour l'affichage d'un type d'activité
/// Utilisé dans toutes les réponses GET
struct TypeOfActivityDTO: Content {
    /// Identifiant unique du type d'activité
    let id: UUID?
    
    /// Le nom de l'activité
    let name: NameOfActivity
}
