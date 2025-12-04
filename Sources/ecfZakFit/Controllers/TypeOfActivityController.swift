//
//  TypeOfActivity.swift
//  ecfZakFit
//
//  Created by cyrilH on 28/11/2025.
//

import Vapor
import Fluent

// MARK: - TypeOfActivityController
/// Contrôleur gérant les types d'activités physiques (cardio, musculation, yoga, etc.)
struct TypeOfActivityController: RouteCollection {
    
    // MARK: - Routes Configuration
    /// Configure les routes pour la gestion des types d'activités
    /// - Parameter routes: Le constructeur de routes Vapor
    func boot(routes: any RoutesBuilder) throws {
        let types = routes.grouped("types-activity")
        
        // Routes publiques
        types.get("", use: getAll)              // GET /types-activity - Récupérer tous les types
        types.post(use: create)                  // POST /types-activity - Créer un type
        
        // Routes avec paramètre :typeID
        types.group(":typeID") { type in
            type.get(use: getById)               // GET /types-activity/:typeID - Récupérer un type par ID
            type.delete(use: delete)             // DELETE /types-activity/:typeID - Supprimer un type
        }
    }
    
    // MARK: - GET /types-activity
    /// Récupère la liste complète de tous les types d'activités disponibles
    /// - Parameter req: La requête HTTP reçue
    /// - Returns: Un tableau de `TypeOfActivityDTO` contenant tous les types d'activités
    func getAll(req: Request) async throws -> [TypeOfActivityDTO] {
        let typeOfActivity = try await TypeOfActivity.query(on: req.db).all()
        
        return typeOfActivity.map { type in
            TypeOfActivityDTO(
                id: type.id,
                name: type.nameOfActivity
            )
        }
    }
    
    // MARK: - GET /types-activity/:typeID
    /// Récupère un type d'activité spécifique par son identifiant UUID
    /// - Parameter req: La requête HTTP contenant l'ID dans les paramètres d'URL
    /// - Returns: Un `TypeOfActivityDTO` correspondant à l'ID fourni
    /// - Throws:
    ///   - `Abort(.badRequest)` si l'ID fourni n'est pas un UUID valide
    ///   - `Abort(.notFound)` si aucun type d'activité ne correspond à cet ID
    func getById(req: Request) async throws -> TypeOfActivityDTO {
        // Validation et extraction de l'UUID depuis les paramètres d'URL
        guard let typeIDString = req.parameters.get("typeID"),
              let typeID = UUID(uuidString: typeIDString) else {
            throw Abort(.badRequest, reason: "Invalid activity type ID format")
        }
        
        // Recherche du type d'activité dans la base de données
        guard let typeOfActivity = try await TypeOfActivity.find(typeID, on: req.db) else {
            throw Abort(.notFound, reason: "Activity type not found")
        }
        
        return TypeOfActivityDTO(
            id: typeOfActivity.id,
            name: typeOfActivity.nameOfActivity
        )
    }
    
    // MARK: - POST /types-activity
    /// Crée un nouveau type d'activité dans le système
    /// - Parameter req: La requête HTTP contenant le DTO de création dans le body
    /// - Returns: Un `TypeOfActivityDTO` représentant le type d'activité créé
    /// - Throws:
    ///   - `Abort(.conflict)` si un type d'activité avec ce nom existe déjà
    ///   - Erreurs de décodage si le body JSON est invalide
    func create(req: Request) async throws -> TypeOfActivityDTO {
        // Décodage du DTO depuis le body de la requête
        let dto = try req.content.decode(CreateTypeOfActivityDTO.self)
        
        // Vérification de l'unicité du nom d'activité
        if let _ = try await TypeOfActivity.query(on: req.db)
            .filter(\.$nameOfActivity == dto.nameOfActivity)
            .first() {
            throw Abort(.conflict, reason: "This activity type already exists")
        }
        
        // Création et sauvegarde du nouveau type d'activité
        let type = TypeOfActivity(nameOfActivity: dto.nameOfActivity)
        try await type.save(on: req.db)
        
        return TypeOfActivityDTO(
            id: type.id,
            name: type.nameOfActivity
        )
    }
    
    // MARK: - DELETE /types-activity/:typeID
    /// Supprime un type d'activité existant de la base de données
    /// - Parameter req: La requête HTTP contenant l'ID dans les paramètres d'URL
    /// - Returns: Un statut HTTP `.noContent` (204) en cas de succès
    /// - Throws: `Abort(.notFound)` si le type d'activité n'existe pas
    /// - Warning: La suppression en cascade supprimera également toutes les activités liées à ce type
    func delete(req: Request) async throws -> HTTPStatus {
        // Recherche du type d'activité à supprimer
        guard let typeOfActivity = try await TypeOfActivity.find(req.parameters.get("typeID"), on: req.db) else {
            throw Abort(.notFound, reason: "Activity type not found")
        }
        
        // Suppression du type d'activité (cascade vers les activités liées)
        try await typeOfActivity.delete(on: req.db)
        
        return .noContent
    }
}
