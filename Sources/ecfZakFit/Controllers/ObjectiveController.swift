//
//  ObjectiveController.swift
//  ecfZakFit
//
//  Created by cyrilH on 28/11/2025.
//

import Vapor
import Fluent

// MARK: - Objective Controller
/// Contrôleur gérant les objectifs personnels des utilisateurs
/// Supporte trois types d'objectifs : poids, activité et calories
struct ObjectiveController: RouteCollection {
    
    // MARK: - Routes Configuration
    /// Configure toutes les routes liées aux objectifs
    /// - Parameter routes: Le constructeur de routes Vapor
    func boot(routes: any RoutesBuilder) throws {
        let objectives = routes.grouped("objectives").grouped(JWTMiddleware())
        
        objectives.post(use: create)                           // POST /objectives - Créer des objectifs
        objectives.get(use: getAll)                            // GET /objectives - Tous les objectifs
        objectives.get("last-three", use: getLastObjectivesByType)  // GET /objectives/last-three - Derniers par type
        objectives.patch(":objectiveID", use: update)          // PATCH /objectives/:objectiveID - Mettre à jour
        objectives.delete(":objectiveID", use: delete)         // DELETE /objectives/:objectiveID - Supprimer
    }
    
    // MARK: - POST /objectives
    /// Crée un ou plusieurs objectifs pour l'utilisateur authentifié
    /// Permet de créer simultanément des objectifs de poids, activité et calories
    ///
    /// - Parameter req: La requête HTTP contenant le DTO de création et le token JWT
    /// - Returns: Un tableau de `ObjectiveDisplayDTO` représentant les objectifs créés
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    /// - Note: Les champs du DTO sont optionnels, seuls les objectifs fournis sont créés
    func create(req: Request) async throws -> [ObjectiveDisplayDTO] {
        let dto = try req.content.decode(CreateObjectivesDTO.self)
        
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        var createdObjectives: [ObjectiveDisplayDTO] = []
        
        // MARK: Création de l'objectif de poids (si fourni)
        if let weightValue = dto.weight {
            let obj = Objective(type: .weight, value: weightValue, userID: userID)
            try await obj.save(on: req.db)
            createdObjectives.append(ObjectiveDisplayDTO(
                id: obj.id,
                type: obj.type,
                value: obj.value,
                date: obj.date?.toString()
            ))
        }
        
        // MARK: Création de l'objectif d'activité (si fourni)
        if let activityValue = dto.activity {
            let obj = Objective(type: .activity, value: activityValue, userID: userID)
            try await obj.save(on: req.db)
            createdObjectives.append(ObjectiveDisplayDTO(
                id: obj.id,
                type: obj.type,
                value: obj.value,
                date: obj.date?.toString()
            ))
        }
        
        // MARK: Création de l'objectif calorique (si fourni)
        if let caloricValue = dto.caloric {
            let obj = Objective(type: .caloric, value: caloricValue, userID: userID)
            try await obj.save(on: req.db)
            createdObjectives.append(ObjectiveDisplayDTO(
                id: obj.id,
                type: obj.type,
                value: obj.value,
                date: obj.date?.toString()
            ))
        }
        
        return createdObjectives
    }
    
    // MARK: - GET /objectives
    /// Récupère tous les objectifs de l'utilisateur authentifié
    ///
    /// - Parameter req: La requête HTTP avec le token JWT
    /// - Returns: Un tableau de `ObjectiveDisplayDTO` contenant tous les objectifs
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    func getAll(req: Request) async throws -> [ObjectiveDisplayDTO] {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        // Chargement de tous les objectifs de l'utilisateur
        let objectives = try await Objective.query(on: req.db)
            .filter(\.$user.$id == userID)
            .all()
        
        return objectives.map { obj in
            ObjectiveDisplayDTO(
                id: obj.id,
                type: obj.type,
                value: obj.value,
                date: obj.date?.toString()
            )
        }
    }
    
    // MARK: - GET /objectives/last-three
    /// Récupère le dernier objectif de chaque type pour l'utilisateur
    /// Retourne au maximum 3 objectifs (un par type : weight, activity, caloric)
    ///
    /// - Parameter req: La requête HTTP avec le token JWT
    /// - Returns: Un tableau de `ObjectiveDisplayDTO` contenant les derniers objectifs par type
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    func getLastObjectivesByType(req: Request) async throws -> [ObjectiveDisplayDTO] {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        var results: [ObjectiveDisplayDTO] = []
        
        // Parcours de tous les types d'objectifs possibles
        for type in TypeOfObjective.allCases {
            // Recherche du dernier objectif de ce type
            if let lastObj = try await Objective.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$type == type)
                .sort(\.$date, .descending)
                .first()
            {
                results.append(
                    ObjectiveDisplayDTO(
                        id: lastObj.id,
                        type: lastObj.type,
                        value: lastObj.value,
                        date: lastObj.date?.toString()
                    )
                )
            }
        }
        
        return results
    }
    
    // MARK: - PATCH /objectives/:objectiveID
    /// Met à jour ou crée des objectifs
    /// Si un objectif du type existe déjà, il est mis à jour, sinon il est créé
    ///
    /// - Parameter req: La requête HTTP contenant le DTO de mise à jour
    /// - Returns: Un tableau de `ObjectiveDisplayDTO` représentant les objectifs modifiés/créés
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    /// - Note: Cette fonction implémente une logique "upsert" (update or insert)
    func update(req: Request) async throws -> [ObjectiveDisplayDTO] {
        let dto = try req.content.decode(UpdateObjectivesDTO.self)
        
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        var updatedObjectives: [ObjectiveDisplayDTO] = []
        
        /// Fonction helper pour mettre à jour ou créer un objectif
        /// - Parameters:
        ///   - type: Le type d'objectif
        ///   - value: La nouvelle valeur de l'objectif
        func updateOrCreate(type: TypeOfObjective, value: Int) async throws {
            // Recherche du dernier objectif de ce type
            if let existing = try await Objective.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$type == type)
                .sort(\.$date, .descending)
                .first()
            {
                // Mise à jour de l'objectif existant
                existing.value = value
                try await existing.save(on: req.db)
                updatedObjectives.append(ObjectiveDisplayDTO(
                    id: existing.id,
                    type: existing.type,
                    value: existing.value,
                    date: existing.date?.toString()
                ))
            } else {
                // Création d'un nouvel objectif
                let obj = Objective(type: type, value: value, userID: userID)
                try await obj.save(on: req.db)
                updatedObjectives.append(ObjectiveDisplayDTO(
                    id: obj.id,
                    type: obj.type,
                    value: obj.value,
                    date: obj.date?.toString()
                ))
            }
        }
        
        // Mise à jour/création des objectifs fournis
        if let weightValue = dto.weight {
            try await updateOrCreate(type: .weight, value: weightValue)
        }
        if let activityValue = dto.activity {
            try await updateOrCreate(type: .activity, value: activityValue)
        }
        if let caloricValue = dto.caloric {
            try await updateOrCreate(type: .caloric, value: caloricValue)
        }
        
        return updatedObjectives
    }
    
    // MARK: - DELETE /objectives/:objectiveID
    /// Supprime un objectif spécifique
    /// Vérifie que l'objectif appartient bien à l'utilisateur authentifié
    ///
    /// - Parameter req: La requête HTTP contenant l'ID de l'objectif
    /// - Returns: Un statut HTTP `.noContent` (204) en cas de succès
    /// - Throws:
    ///   - `Abort(.notFound)` si l'utilisateur ou l'objectif n'existe pas
    ///   - `Abort(.badRequest)` si l'ID est invalide
    ///   - `Abort(.forbidden)` si l'objectif n'appartient pas à l'utilisateur
    func delete(req: Request) async throws -> HTTPStatus {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        // Validation de l'UUID
        guard let objectiveID = req.parameters.get("objectiveID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid objective ID format")
        }
        
        // Recherche de l'objectif
        guard let obj = try await Objective.find(objectiveID, on: req.db) else {
            throw Abort(.notFound, reason: "Objective not found")
        }
        
        // Vérification de la propriété de l'objectif
        guard obj.$user.id == userID else {
            throw Abort(.forbidden, reason: "You cannot delete this objective")
        }
        
        try await obj.delete(on: req.db)
        return .noContent
    }
}
