//
//  FoodController.swift
//  ecfZakFit
//
//  Created by cyrilH on 27/11/2025.
//

import Fluent
import Vapor
import JWT
import SQLKit

// MARK: - Food Controller
/// Contrôleur gérant les aliments du système
/// Permet la gestion complète des aliments (CRUD) et supporte à la fois :
/// - Les aliments système (disponibles pour tous les utilisateurs)
/// - Les aliments personnalisés créés par les utilisateurs
struct FoodController: RouteCollection {
    
    // MARK: - Routes Configuration
    /// Configure toutes les routes liées aux aliments
    /// - Parameter routes: Le constructeur de routes Vapor
    func boot(routes: any RoutesBuilder) throws {
        let foods = routes.grouped("foods")
        
        // Routes publiques
        foods.get("", use: getAll)                    // GET /foods - Tous les aliments système
        foods.post("admin", use: bulkCreate)          // POST /foods/admin - Création en masse (admin)
        
        // Routes protégées par JWT
        let protectedFood = foods.grouped(JWTMiddleware())
        protectedFood.post(use: create)               // POST /foods - Créer un aliment personnalisé
        protectedFood.get("me", use: getAllWithUser)  // GET /foods/me - Aliments système + personnalisés
        
        // Routes avec paramètre :foodID
        foods.group(":foodID") { food in
            food.get(use: getById)                    // GET /foods/:foodID
            food.patch(use: update)                   // PATCH /foods/:foodID
            food.delete(use: delete)                  // DELETE /foods/:foodID
        }
    }
    
    // MARK: - GET /foods
    /// Récupère tous les aliments système (non liés à un utilisateur spécifique)
    /// - Parameter req: La requête HTTP
    /// - Returns: Un tableau de `AllFoodDTO` contenant tous les aliments système
    /// - Note: Cette route est publique et retourne uniquement les aliments partagés
    func getAll(req: Request) async throws -> [AllFoodDTO] {
        
        /// Structure pour décoder les résultats de la requête SQL brute
        struct Row: Decodable {
            var id: UUID
            var name: String
            var category: String
            var categoryPreference: String
            var foodCalories: Double
            var foodProteins: Double
            var carbohydrateFromFood: Double
            var foodLipid: Double
            var calculationUnit: Int
        }
        
        let sql = req.db as! any SQLDatabase
        
        // Requête SQL pour récupérer tous les aliments
        let rows = try await sql.raw("""
            SELECT 
                id,
                name,
                category,
                categoryPreference,
                foodCalories,
                foodProteins,
                carbohydrateFromFood,
                foodLipid,
                calculationUnit
            FROM foods
            WHERE user_id IS NULL
            """)
            .all(decoding: Row.self)
        
        return rows.map { row in
            AllFoodDTO(
                id: row.id,
                name: row.name,
                category: CategoryFood(rawValue: row.category) ?? .fruit,
                categoryPreference: UserTypePreferredPowerSupply(rawValue: row.categoryPreference) ?? .flexitarian,
                foodCalories: row.foodCalories,
                foodProteins: row.foodProteins,
                carbohydrateFromFood: row.carbohydrateFromFood,
                foodLipid: row.foodLipid,
                calculationUnit: row.calculationUnit
            )
        }
    }
    
    // MARK: - GET /foods/me
    /// Récupère tous les aliments accessibles par l'utilisateur authentifié
    /// Inclut les aliments système ET les aliments personnalisés de l'utilisateur
    /// - Parameter req: La requête HTTP avec le token JWT
    /// - Returns: Un tableau de `AllFoodDTO` contenant tous les aliments accessibles
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    func getAllWithUser(req: Request) async throws -> [AllFoodDTO] {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        // Requête pour récupérer les aliments système OU les aliments de l'utilisateur
        let foods = try await Food.query(on: req.db)
            .group(.or) { group in
                group.filter(\.$user.$id == nil)      // Aliments système (user_id NULL)
                group.filter(\.$user.$id == userID)   // Aliments personnalisés de l'utilisateur
            }
            .all()
        
        return foods.map { food in
            AllFoodDTO(
                id: food.id,
                name: food.name,
                category: food.category,
                categoryPreference: food.categoryPreference,
                foodCalories: food.foodCalories,
                foodProteins: food.foodProteins,
                carbohydrateFromFood: food.carbohydrateFromFood,
                foodLipid: food.foodLipide,
                calculationUnit: food.calculationUnit
            )
        }
    }
    
    // MARK: - GET /foods/:foodID
    /// Récupère un aliment spécifique par son identifiant
    /// - Parameter req: La requête HTTP contenant l'ID dans les paramètres
    /// - Returns: Un `AllFoodDTO` représentant l'aliment
    /// - Throws: `Abort(.notFound)` si l'aliment n'existe pas
    func getById(req: Request) async throws -> AllFoodDTO {
        guard let food = try await Food.find(req.parameters.get("foodID"), on: req.db) else {
            throw Abort(.notFound, reason: "Food not found")
        }
        
        return AllFoodDTO(
            id: food.id,
            name: food.name,
            category: food.category,
            categoryPreference: food.categoryPreference,
            foodCalories: food.foodCalories,
            foodProteins: food.foodProteins,
            carbohydrateFromFood: food.carbohydrateFromFood,
            foodLipid: food.foodLipide,
            calculationUnit: food.calculationUnit
        )
    }
    
    // MARK: - POST /foods
    /// Crée un nouvel aliment personnalisé pour l'utilisateur authentifié
    /// - Parameter req: La requête HTTP contenant le DTO de création et le token JWT
    /// - Returns: Un `AllFoodDTO` représentant l'aliment créé
    /// - Throws:
    ///   - `Abort(.notFound)` si l'utilisateur n'existe pas
    ///   - `Abort(.badRequest)` si les validations échouent
    func create(req: Request) async throws -> AllFoodDTO {
        let dto = try req.content.decode(CreateFoodDTO.self)
        
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        // MARK: Validations
        guard !dto.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Food name cannot be empty")
        }
        
        guard dto.foodCalories >= 0 else {
            throw Abort(.badRequest, reason: "Calories cannot be negative")
        }
        
        guard dto.foodProteins >= 0 else {
            throw Abort(.badRequest, reason: "Proteins cannot be negative")
        }
        
        guard dto.carbohydrateFromFood >= 0 else {
            throw Abort(.badRequest, reason: "Carbohydrates cannot be negative")
        }
        
        guard dto.foodLipid >= 0 else {
            throw Abort(.badRequest, reason: "Lipids cannot be negative")
        }
        
        guard dto.calculationUnit == 1 || dto.calculationUnit == 100 else {
            throw Abort(.badRequest, reason: "Calculation unit must be 1 or 100")
        }
        
        // Création de l'aliment
        let food = Food(
            name: dto.name,
            category: dto.category,
            categoryPreference: dto.categoryPreference,
            foodCalories: dto.foodCalories,
            foodProteins: dto.foodProteins,
            carbohydrateFromFood: dto.carbohydrateFromFood,
            foodLipide: dto.foodLipid,
            calculationUnit: dto.calculationUnit,
            userID: userID
        )
        
        try await food.save(on: req.db)
        
        return AllFoodDTO(
            id: food.id,
            name: food.name,
            category: food.category,
            categoryPreference: food.categoryPreference,
            foodCalories: food.foodCalories,
            foodProteins: food.foodProteins,
            carbohydrateFromFood: food.carbohydrateFromFood,
            foodLipid: food.foodLipide,
            calculationUnit: food.calculationUnit
        )
    }
    
    // MARK: - PATCH /foods/:foodID
    /// Met à jour un aliment existant
    /// - Parameter req: La requête HTTP contenant le DTO de mise à jour
    /// - Returns: Un `AllFoodDTO` représentant l'aliment mis à jour
    /// - Throws: `Abort(.notFound)` si l'aliment n'existe pas
    /// - Note: Tous les champs du DTO sont optionnels, seuls les champs fournis sont mis à jour
    func update(req: Request) async throws -> AllFoodDTO {
        let dto = try req.content.decode(UpdateFoodDTO.self)
        
        guard let food = try await Food.find(req.parameters.get("foodID"), on: req.db) else {
            throw Abort(.notFound, reason: "Food not found")
        }
        
        // Mise à jour conditionnelle des champs
        if let name = dto.name { food.name = name }
        if let category = dto.category { food.category = category }
        if let categoryPref = dto.categoryPreference { food.categoryPreference = categoryPref }
        if let calories = dto.foodCalories { food.foodCalories = calories }
        if let proteins = dto.foodProteins { food.foodProteins = proteins }
        if let carbs = dto.carbohydrateFromFood { food.carbohydrateFromFood = carbs }
        if let lipids = dto.foodLipid { food.foodLipide = lipids }
        if let unit = dto.calculationUnit { food.calculationUnit = unit }
        
        try await food.save(on: req.db)
        
        return AllFoodDTO(
            id: food.id,
            name: food.name,
            category: food.category,
            categoryPreference: food.categoryPreference,
            foodCalories: food.foodCalories,
            foodProteins: food.foodProteins,
            carbohydrateFromFood: food.carbohydrateFromFood,
            foodLipid: food.foodLipide,
            calculationUnit: food.calculationUnit
        )
    }
    
    // MARK: - DELETE /foods/:foodID
    /// Supprime un aliment existant
    /// - Parameter req: La requête HTTP contenant l'ID de l'aliment
    /// - Returns: Un statut HTTP `.noContent` (204) en cas de succès
    /// - Throws: `Abort(.notFound)` si l'aliment n'existe pas
    /// - Warning: La suppression en cascade supprimera aussi les entrées dans mealsFoods
    func delete(req: Request) async throws -> HTTPStatus {
        guard let food = try await Food.find(req.parameters.get("foodID"), on: req.db) else {
            throw Abort(.notFound, reason: "Food not found")
        }
        
        try await food.delete(on: req.db)
        return .noContent
    }
    
    // MARK: - POST /foods/admin
    /// Crée plusieurs aliments système en une seule requête (bulk creation)
    /// - Parameter req: La requête HTTP contenant un tableau d'aliments à créer
    /// - Returns: Un tableau de `AllFoodDTO` représentant les aliments créés
    /// - Note: Cette route est destinée aux administrateurs pour peupler la base de données
    /// - Warning: Aucune authentification n'est requise actuellement (à sécuriser en production)
    func bulkCreate(req: Request) async throws -> [AllFoodDTO] {
        /// Structure pour recevoir un tableau d'aliments
        struct BulkFoodInput: Content {
            let foods: [CreateFoodDTO]
        }
        
        let input = try req.content.decode(BulkFoodInput.self)
        var createdFoods: [AllFoodDTO] = []
        
        // Création de chaque aliment dans la boucle
        for dto in input.foods {
            let food = Food(
                name: dto.name,
                category: dto.category,
                categoryPreference: dto.categoryPreference,
                foodCalories: dto.foodCalories,
                foodProteins: dto.foodProteins,
                carbohydrateFromFood: dto.carbohydrateFromFood,
                foodLipide: dto.foodLipid,
                calculationUnit: dto.calculationUnit
                // userID: nil (aliment système)
            )
            
            try await food.save(on: req.db)
            
            createdFoods.append(
                AllFoodDTO(
                    id: food.id,
                    name: food.name,
                    category: food.category,
                    categoryPreference: food.categoryPreference,
                    foodCalories: food.foodCalories,
                    foodProteins: food.foodProteins,
                    carbohydrateFromFood: food.carbohydrateFromFood,
                    foodLipid: food.foodLipide,
                    calculationUnit: food.calculationUnit
                )
            )
        }
        
        return createdFoods
    }
}
