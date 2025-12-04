//
//  ActivityController.swift
//  ecfZakFit
//
//  Created by cyrilH on 28/11/2025.
//

import Fluent
import Vapor
import JWT
import SQLKit

// MARK: - Activity Controller
/// Contrôleur gérant les activités physiques des utilisateurs
/// Permet de créer, consulter, filtrer et récupérer les activités sportives
struct ActivityController: RouteCollection {
    
    // MARK: - Routes Configuration
    /// Configure toutes les routes liées aux activités
    /// - Parameter routes: Le constructeur de routes Vapor
    func boot(routes: any RoutesBuilder) throws {
        let activities = routes.grouped("activities")
        
        // Routes publiques
        activities.get("", use: getAll)  // GET /activities - Récupérer toutes les activités
        
        // Routes protégées par JWT
        let protectedActivity = activities.grouped(JWTMiddleware())
        
        protectedActivity.post(use: create)                      // POST /activities - Créer une activité
        protectedActivity.get("today", use: getTodayActivities)  // GET /activities/today - Activités du jour
        protectedActivity.get("filter", use: filterActivities)   // GET /activities/filter - Filtrer les activités
        
        // Routes avec paramètre (commentées car non utilisées actuellement)
        activities.group(":activityID") { activity in
            // activity.get(use: getById)
            // activity.patch(use: update)
            // activity.delete(use: delete)
        }
    }
    
    // MARK: - GET /activities
    /// Récupère toutes les activités existantes dans le système (toutes utilisateurs confondus)
    /// - Parameter req: La requête HTTP
    /// - Returns: Un tableau de `AllActivityDTO` contenant toutes les activités
    /// - Note: Cette route est publique et n'est pas filtrée par utilisateur
    func getAll(req: Request) async throws -> [AllActivityDTO] {
        
        /// Structure pour décoder les résultats de la requête SQL brute
        struct Row: Decodable {
            var activity_id: UUID
            var type_id: UUID
            var type_name: String
            var duration: Int
            var calories_burned: Int
            var activity_name: String
            var activity_date: Date
        }
        
        // Récupération de l'interface SQL pour exécuter une requête brute
        let sql = req.db as! any SQLDatabase
        
        // Requête SQL avec JOIN pour récupérer les activités et leurs types
        let rows = try await sql.raw("""
            SELECT 
                a.id AS activity_id,
                toa.id AS type_id,
                toa.name_of_activity AS type_name,
                COALESCE(a.duration, 0) AS duration,
                COALESCE(a.calories_burned, 0) AS calories_burned,
                a.name AS activity_name,
                a.date AS activity_date
            FROM activity a
            JOIN type_of_activity toa ON toa.id = a.type_of_activity_id
            """)
            .all(decoding: Row.self)
        
        // Transformation des résultats SQL en DTOs
        return rows.map { row in
            AllActivityDTO(
                id: row.activity_id,
                type: TypeOfActivityDTO(
                    id: row.type_id,
                    name: NameOfActivity(rawValue: row.type_name) ?? .cardio
                ),
                duration: row.duration,
                caloriesBurned: row.calories_burned,
                name: row.activity_name,
                date: row.activity_date
            )
        }
    }
    
    // MARK: - GET /activities/:activityID
    /// Récupère une activité spécifique par son identifiant
    /// - Parameter req: La requête HTTP contenant l'ID dans les paramètres
    /// - Returns: Un `AllActivityDTO` représentant l'activité
    /// - Throws:
    ///   - `Abort(.badRequest)` si l'ID est invalide
    ///   - `Abort(.notFound)` si l'activité n'existe pas
    func getById(req: Request) async throws -> AllActivityDTO {
        // Validation de l'UUID dans les paramètres d'URL
        guard let activityIDString = req.parameters.get("activityID"),
              let activityID = UUID(uuidString: activityIDString) else {
            throw Abort(.badRequest, reason: "Invalid activity ID format")
        }
        
        // Recherche de l'activité avec son type chargé
        guard let activity = try await Activity.query(on: req.db)
            .filter(\.$id == activityID)
            .with(\.$typeOfActivity)
            .first() else {
            throw Abort(.notFound, reason: "Activity not found")
        }
        
        return AllActivityDTO(
            id: activity.id,
            type: TypeOfActivityDTO(
                id: activity.typeOfActivity.id,
                name: activity.typeOfActivity.nameOfActivity
            ),
            duration: activity.duration ?? 0,
            caloriesBurned: activity.caloriesBurned ?? 0,
            name: activity.name,
            date: activity.date
        )
    }
    
    // MARK: - POST /activities
    /// Crée une nouvelle activité pour l'utilisateur authentifié
    /// - Parameter req: La requête HTTP contenant le DTO de création et le token JWT
    /// - Returns: Un `AllActivityDTO` représentant l'activité créée
    /// - Throws:
    ///   - `Abort(.notFound)` si l'utilisateur ou le type d'activité n'existe pas
    ///   - Erreurs de décodage si le body JSON est invalide
    func create(req: Request) async throws -> AllActivityDTO {
        // Décodage du DTO depuis le body de la requête
        let dto = try req.content.decode(CreateActivityDTO.self)
        
        // Récupération de l'utilisateur depuis le token JWT
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        // Vérification que le type d'activité existe
        guard let type = try await TypeOfActivity.find(dto.type, on: req.db) else {
            throw Abort(.notFound, reason: "Activity type not found")
        }
        
        // Création de l'activité
        let activity = Activity(
            duration: dto.duration,
            caloriesBurned: dto.caloriesBurned,
            name: dto.name,
            userID: userID,
            typeOfActivityID: type.id!
        )
        
        // Sauvegarde dans la base de données
        try await activity.save(on: req.db)
        
        // Chargement de la relation typeOfActivity
        try await activity.$typeOfActivity.load(on: req.db)
        
        return AllActivityDTO(
            id: activity.id,
            type: TypeOfActivityDTO(
                id: activity.typeOfActivity.id,
                name: activity.typeOfActivity.nameOfActivity
            ),
            duration: activity.duration ?? 0,
            caloriesBurned: activity.caloriesBurned ?? 0,
            name: activity.name,
            date: activity.date
        )
    }
    
    // MARK: - PATCH /activities/:activityID
    /// Met à jour une activité existante
    /// - Parameter req: La requête HTTP contenant le DTO de mise à jour
    /// - Returns: Un `AllActivityDTO` représentant l'activité mise à jour
    /// - Throws: `Abort(.notFound)` si l'activité ou le type d'activité n'existe pas
    func update(req: Request) async throws -> AllActivityDTO {
        let dto = try req.content.decode(UpdateActivityDTO.self)
        
        guard let activity = try await Activity.find(req.parameters.get("activityID"), on: req.db) else {
            throw Abort(.notFound, reason: "Activity not found")
        }
        
        // Mise à jour uniquement des champs fournis (optionnels)
        if let name = dto.name { activity.name = name }
        if let duration = dto.duration { activity.duration = duration }
        if let calories = dto.caloriesBurned { activity.caloriesBurned = calories }
        
        // Modification du type d'activité si fourni
        if let typeID = dto.typeOfActivityID {
            guard let type = try await TypeOfActivity.find(typeID, on: req.db) else {
                throw Abort(.notFound, reason: "Activity type not found")
            }
            activity.$typeOfActivity.id = try type.requireID()
        }
        
        try await activity.save(on: req.db)
        try await activity.$typeOfActivity.load(on: req.db)
        
        return AllActivityDTO(
            id: activity.id,
            type: TypeOfActivityDTO(
                id: activity.typeOfActivity.id,
                name: activity.typeOfActivity.nameOfActivity
            ),
            duration: activity.duration,
            caloriesBurned: activity.caloriesBurned,
            name: activity.name,
            date: activity.date
        )
    }
    
    // MARK: - DELETE /activities/:activityID
    /// Supprime une activité existante
    /// - Parameter req: La requête HTTP contenant l'ID de l'activité
    /// - Returns: Un statut HTTP `.noContent` (204) en cas de succès
    /// - Throws: `Abort(.notFound)` si l'activité n'existe pas
    func delete(req: Request) async throws -> HTTPStatus {
        guard let activity = try await Activity.find(req.parameters.get("activityID"), on: req.db) else {
            throw Abort(.notFound, reason: "Activity not found")
        }
        
        try await activity.delete(on: req.db)
        return .noContent
    }
    
    // MARK: - GET /activities/today
    /// Récupère toutes les activités du jour pour l'utilisateur authentifié
    /// - Parameter req: La requête HTTP avec le token JWT
    /// - Returns: Un tableau de `AllActivityDTO` contenant les activités du jour
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    func getTodayActivities(req: Request) async throws -> [AllActivityDTO] {
        // Récupération de l'utilisateur depuis le token JWT
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        // Calcul des bornes du jour actuel
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // Requête filtrée par utilisateur et date
        let activities = try await Activity.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$date >= today)
            .filter(\.$date < tomorrow)
            .with(\.$typeOfActivity)
            .all()
        
        return activities.map { activity in
            AllActivityDTO(
                id: activity.id,
                type: TypeOfActivityDTO(
                    id: activity.$typeOfActivity.id,
                    name: activity.typeOfActivity.nameOfActivity
                ),
                duration: activity.duration ?? 0,
                caloriesBurned: activity.caloriesBurned ?? 0,
                name: activity.name,
                date: activity.date
            )
        }
    }
    
    // MARK: - GET /activities/filter
    /// Filtre les activités de l'utilisateur selon plusieurs critères
    ///
    /// Query parameters disponibles :
    /// - `type` : Filtrer par nom d'activité (ex: "cardio", "bodybuilding", "yoga")
    /// - `date` : Filtrer par date exacte au format yyyy-MM-dd
    /// - `start` : Date de début de plage au format yyyy-MM-dd
    /// - `end` : Date de fin de plage au format yyyy-MM-dd
    /// - `period` : Période prédéfinie ("week" | "month")
    /// - `sort` : Ordre de tri par durée ("asc" | "desc", défaut: "desc")
    ///
    /// - Parameter req: La requête HTTP avec les query parameters
    /// - Returns: Un tableau de `AllActivityDTO` filtré et trié
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    func filterActivities(req: Request) async throws -> [AllActivityDTO] {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        // Lecture des paramètres de query
        let type = req.query[String.self, at: "type"]
        let date = req.query[String.self, at: "date"]
        let start = req.query[String.self, at: "start"]
        let end = req.query[String.self, at: "end"]
        let period = req.query[String.self, at: "period"]
        let sortOrder = req.query[String.self, at: "sort"]
        
        // Construction de la requête de base filtrée par utilisateur
        var query = Activity.query(on: req.db)
            .filter(\.$user.$id == userID)
            .with(\.$typeOfActivity)
        
        // MARK: Filtre par type d'activité
        if let typeName = type,
           let enumValue = NameOfActivity(rawValue: typeName) {
            let matchingTypes = try await TypeOfActivity.query(on: req.db)
                .filter(\.$nameOfActivity == enumValue)
                .all()
            let typeIDs = matchingTypes.compactMap { $0.id }
            if !typeIDs.isEmpty {
                query = query.filter(\.$typeOfActivity.$id ~~ typeIDs)
            }
        }
        
        let calendar = Calendar.current
        
        // MARK: Filtre par date exacte
        if let date = date, let parsedDate = date.toDate() {
            let dayStart = calendar.startOfDay(for: parsedDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            query = query
                .filter(\.$date >= dayStart)
                .filter(\.$date < dayEnd)
        }
        
        // MARK: Filtre par plage de dates (start & end)
        if let start = start, let startDate = start.toDate(),
           let end = end, let endDate = end.toDate() {
            let startDay = calendar.startOfDay(for: startDate)
            let endDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!
            query = query
                .filter(\.$date >= startDay)
                .filter(\.$date < endDay)
        }
        
        // MARK: Filtre par période (semaine / mois courant)
        if let period = period {
            let now = Date()
            switch period.lowercased() {
            case "week":
                let startWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                query = query.filter(\.$date >= startWeek)
            case "month":
                let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                query = query.filter(\.$date >= startMonth)
            default:
                break
            }
        }
        
        // MARK: Tri par durée
        if let sortOrder = sortOrder?.lowercased() {
            switch sortOrder {
            case "asc":
                query = query.sort(\.$duration, .ascending)
            case "desc":
                query = query.sort(\.$duration, .descending)
            default:
                query = query.sort(\.$duration, .descending)
            }
        } else {
            // Tri par défaut : décroissant
            query = query.sort(\.$duration, .descending)
        }
        
        // Exécution de la requête
        let activities = try await query.all()
        
        return activities.map { activity in
            AllActivityDTO(
                id: activity.id,
                type: TypeOfActivityDTO(
                    id: activity.typeOfActivity.id,
                    name: activity.typeOfActivity.nameOfActivity
                ),
                duration: activity.duration ?? 0,
                caloriesBurned: activity.caloriesBurned ?? 0,
                name: activity.name,
                date: activity.date
            )
        }
    }
}
