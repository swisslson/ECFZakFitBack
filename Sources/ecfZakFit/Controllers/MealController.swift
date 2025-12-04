//
//  MealController.swift
//  ecfZakFit
//
//  Created by cyrilH on 28/11/2025.
//

import Vapor
import Fluent

// MARK: - Meal Controller
/// Contrôleur gérant les repas des utilisateurs
/// Un repas est composé de plusieurs aliments (ingrédients) avec leurs quantités
/// Les valeurs nutritionnelles totales sont calculées automatiquement
struct MealController: RouteCollection {
    
    // MARK: - Routes Configuration
    /// Configure toutes les routes liées aux repas
    /// - Parameter routes: Le constructeur de routes Vapor
    func boot(routes: any RoutesBuilder) throws {
        let meals = routes.grouped("meals")
        
        // Routes publiques
        meals.get("", use: getAll)                // GET /meals - Tous les repas
        meals.get(":mealID", use: getById)        // GET /meals/:mealID - Un repas spécifique
        
        // Routes protégées par JWT
        let mealProtected = meals.grouped(JWTMiddleware())
        mealProtected.post(use: create)                    // POST /meals - Créer un repas
        mealProtected.patch(":mealID", use: update)        // PATCH /meals/:mealID - Mettre à jour
        mealProtected.delete(":mealID", use: delete)       // DELETE /meals/:mealID - Supprimer
        mealProtected.get("today", use: getTodayMeals)     // GET /meals/today - Repas du jour
    }
    
    // MARK: - GET /meals
    /// Récupère tous les repas existants avec leurs ingrédients
    /// - Parameter req: La requête HTTP
    /// - Returns: Un tableau de `AllMealDTO` contenant tous les repas
    /// - Note: Cette route est publique et retourne tous les repas (tous utilisateurs)
    func getAll(req: Request) async throws -> [AllMealDTO] {
        let meals = try await Meal.query(on: req.db)
            .with(\.$mealFoods) { mf in
                mf.with(\.$food)
            }
            .all()
        
        // Utilisation de la fonction helper pour construire les DTOs
        return try await meals.asyncMap { meal in
            try await mealToDTO(meal: meal, req: req)
        }
    }
    
    // MARK: - GET /meals/:mealID
    /// Récupère un repas spécifique avec tous ses ingrédients
    /// - Parameter req: La requête HTTP contenant l'ID dans les paramètres
    /// - Returns: Un `AllMealDTO` représentant le repas
    /// - Throws:
    ///   - `Abort(.badRequest)` si l'ID est invalide
    ///   - `Abort(.notFound)` si le repas n'existe pas
    func getById(req: Request) async throws -> AllMealDTO {
        guard let mealIDString = req.parameters.get("mealID"),
              let mealID = UUID(uuidString: mealIDString) else {
            throw Abort(.badRequest, reason: "Invalid meal ID format")
        }
        
        let mealOptional = try await Meal.query(on: req.db)
            .filter(\.$id == mealID)
            .with(\.$mealFoods) { mf in
                mf.with(\.$food)
            }
            .first()
        
        guard let meal = mealOptional else {
            throw Abort(.notFound, reason: "Meal not found")
        }
        
        // Utilisation de la fonction helper pour construire le DTO
        return try await mealToDTO(meal: meal, req: req)
    }
    
    // MARK: - POST /meals
    /// Crée un nouveau repas pour l'utilisateur authentifié
    /// Calcule automatiquement les totaux nutritionnels à partir des ingrédients
    /// - Parameter req: La requête HTTP contenant le DTO de création et le token JWT
    /// - Returns: Un `AllMealDTO` représentant le repas créé
    /// - Throws:
    ///   - `Abort(.notFound)` si l'utilisateur ou un aliment n'existe pas
    ///   - `Abort(.badRequest)` si les validations échouent
    func create(req: Request) async throws -> AllMealDTO {
        let dto = try req.content.decode(CreateMealDTO.self)
        
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        // MARK: Validations
        guard !dto.nameOfMeal.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Meal name cannot be empty")
        }
        
        guard !dto.ingredients.isEmpty else {
            throw Abort(.badRequest, reason: "Meal must contain at least one ingredient")
        }
        
        for (index, ingredient) in dto.ingredients.enumerated() {
            guard ingredient.quantity > 0 else {
                throw Abort(.badRequest, reason: "Ingredient \(index + 1) quantity must be greater than 0")
            }
        }
        
        // MARK: Création du repas avec valeurs initiales à 0
        let meal = Meal(
            nameOfMeal: dto.nameOfMeal,
            totalcalories: 0,
            totalProtein: 0,
            totalLipid: 0,
            totalCarbohydrate: 0,
            typeOfMeal: dto.typeOfMeal,
            userID: userID
        )
        
        try await meal.save(on: req.db)
        
        // MARK: Ajout des ingrédients dans la table pivot
        for ing in dto.ingredients {
            // Vérification que l'aliment existe
            guard let _ = try await Food.find(ing.foodID, on: req.db) else {
                throw Abort(.notFound, reason: "Food with ID \(ing.foodID) not found")
            }
            
            // Création de l'entrée dans la table pivot MealFood
            let mealFood = MealFood(
                quantity: ing.quantity,
                mealID: try meal.requireID(),
                foodID: ing.foodID
            )
            try await mealFood.save(on: req.db)
        }
        
        // MARK: Calcul automatique des totaux nutritionnels
        try await recalcMealTotals(meal: meal, req: req)
        
        // Utilisation de la fonction helper pour construire le DTO de réponse
        return try await mealToDTO(meal: meal, req: req)
    }
    
    // MARK: - PATCH /meals/:mealID
    /// Met à jour un repas existant
    /// Si les ingrédients sont modifiés, les totaux nutritionnels sont recalculés
    /// - Parameter req: La requête HTTP contenant le DTO de mise à jour
    /// - Returns: Un `AllMealDTO` représentant le repas mis à jour
    /// - Throws:
    ///   - `Abort(.badRequest)` si l'ID est invalide
    ///   - `Abort(.notFound)` si le repas n'existe pas
    func update(req: Request) async throws -> AllMealDTO {
        let dto = try req.content.decode(UpdateMealDTO.self)
        
        guard let mealID = req.parameters.get("mealID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid meal ID format")
        }
        
        guard let meal = try await Meal.find(mealID, on: req.db) else {
            throw Abort(.notFound, reason: "Meal not found")
        }
        
        // Mise à jour des champs simples
        if let name = dto.nameOfMeal {
            meal.nameOfMeal = name
        }
        if let type = dto.typeOfMeal {
            meal.typeOfMeal = type
        }
        
        // MARK: Mise à jour des ingrédients
        if let ingredients = dto.ingredients {
            // Suppression des anciennes entrées dans la table pivot
            try await MealFood.query(on: req.db)
                .filter(\.$meal.$id == mealID)
                .delete()
            
            // Création des nouvelles entrées
            for ing in ingredients {
                // Vérification que l'aliment existe
                guard let _ = try await Food.find(ing.foodID, on: req.db) else {
                    throw Abort(.notFound, reason: "Food with ID \(ing.foodID) not found")
                }
                
                let mf = MealFood(
                    quantity: ing.quantity,
                    mealID: mealID,
                    foodID: ing.foodID
                )
                try await mf.save(on: req.db)
            }
        }
        
        // Recalcul automatique des totaux nutritionnels
        try await recalcMealTotals(meal: meal, req: req)
        
        // Utilisation de la fonction helper pour construire le DTO de réponse
        return try await mealToDTO(meal: meal, req: req)
    }
    
    // MARK: - DELETE /meals/:mealID
    /// Supprime un repas existant
    /// Vérifie que le repas appartient bien à l'utilisateur authentifié
    /// - Parameter req: La requête HTTP contenant l'ID du repas
    /// - Returns: Un statut HTTP `.noContent` (204) en cas de succès
    /// - Throws:
    ///   - `Abort(.notFound)` si l'utilisateur ou le repas n'existe pas
    ///   - `Abort(.forbidden)` si le repas n'appartient pas à l'utilisateur
    func delete(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        guard let mealID = req.parameters.get("mealID", as: UUID.self),
              let meal = try await Meal.find(mealID, on: req.db) else {
            throw Abort(.notFound, reason: "Meal not found")
        }
        
        // Vérification de la propriété du repas
        guard meal.$user.id == user.id else {
            throw Abort(.forbidden, reason: "You cannot delete this meal")
        }
        
        try await meal.delete(on: req.db)
        return .noContent
    }
    
    // MARK: - GET /meals/today
    /// Récupère tous les repas du jour pour l'utilisateur authentifié
    /// - Parameter req: La requête HTTP avec le token JWT
    /// - Returns: Un tableau de `AllMealDTO` contenant les repas du jour
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    func getTodayMeals(req: Request) async throws -> [AllMealDTO] {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let meals = try await Meal.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$date >= today)
            .filter(\.$date < tomorrow)
            .with(\.$mealFoods) { mf in
                mf.with(\.$food)
            }
            .all()
        
        // Utilisation de la fonction helper pour construire les DTOs
        return try await meals.asyncMap { meal in
            try await mealToDTO(meal: meal, req: req)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Convertit un modèle `Meal` en `AllMealDTO`
    /// Centralise la logique de transformation pour éviter la duplication de code
    /// - Parameters:
    ///   - meal: Le repas à convertir
    ///   - req: La requête HTTP pour accéder à la base de données
    /// - Returns: Un `AllMealDTO` représentant le repas
    /// - Note: Cette fonction est utilisée dans `getAll()`, `getById()`, `create()`, `update()` et `getTodayMeals()`
    private func mealToDTO(meal: Meal, req: Request) async throws -> AllMealDTO {
        let ingredients = try await getMealIngredients(meal: meal, req: req)
        
        return AllMealDTO(
            id: meal.id,
            nameOfMeal: meal.nameOfMeal,
            typeOfMeal: meal.typeOfMeal,
            ingredients: ingredients,
            totalcalories: meal.totalcalories,
            totalProtein: meal.totalProtein,
            totalLipid: meal.totalLipid,
            totalCarbohydrate: meal.totalCarbohydrate,
            date: meal.date ?? Date()
        )
    }
    
    /// Recalcule les totaux nutritionnels d'un repas à partir de ses ingrédients
    /// Cette fonction est utilisée dans `create()` et `update()`
    /// - Parameters:
    ///   - meal: Le repas à recalculer
    ///   - req: La requête HTTP pour accéder à la base de données
    /// - Note: Réinitialise tous les totaux à zéro puis recalcule en parcourant tous les ingrédients
    private func recalcMealTotals(meal: Meal, req: Request) async throws {
        // Chargement de tous les ingrédients du repas
        let mealFoods = try await meal.$mealFoods.get(on: req.db)
        
        // Réinitialisation des totaux
        meal.totalcalories = 0
        meal.totalProtein = 0
        meal.totalLipid = 0
        meal.totalCarbohydrate = 0
        
        // Calcul des nouveaux totaux
        for mf in mealFoods {
            let food = try await mf.$food.get(on: req.db)
            
            // Calcul du facteur multiplicateur selon l'unité de calcul
            // Si calculationUnit = 100 : valeurs nutritionnelles pour 100g
            // Si calculationUnit = 1 : valeurs nutritionnelles par unité (ex: 1 pomme)
            let factor: Double = (food.calculationUnit == 100)
                ? Double(mf.quantity) / 100.0
                : Double(mf.quantity)
            
            // Ajout aux totaux avec arrondi à 2 décimales
            meal.totalcalories += (food.foodCalories * factor).roundedTo(2)
            meal.totalProtein += (food.foodProteins * factor).roundedTo(2)
            meal.totalLipid += (food.foodLipide * factor).roundedTo(2)
            meal.totalCarbohydrate += (food.carbohydrateFromFood * factor).roundedTo(2)
        }
        
        // Sauvegarde des totaux recalculés
        try await meal.save(on: req.db)
    }
    
    /// Récupère la liste des ingrédients d'un repas avec leurs détails
    /// Cette fonction est utilisée dans `mealToDTO()` qui est appelée partout
    /// - Parameters:
    ///   - meal: Le repas dont on veut récupérer les ingrédients
    ///   - req: La requête HTTP pour accéder à la base de données
    /// - Returns: Un tableau de `MealIngredientDTO` contenant les détails des ingrédients
    /// - Note: Cette fonction charge les relations si elles ne sont pas déjà eager-loaded
    private func getMealIngredients(meal: Meal, req: Request) async throws -> [MealIngredientDTO] {
        let mealFoods = try await meal.$mealFoods.get(on: req.db)
        var ingredients: [MealIngredientDTO] = []
        
        for mf in mealFoods {
            let food = try await mf.$food.get(on: req.db)
            ingredients.append(MealIngredientDTO(
                foodID: food.id!,
                name: food.name,
                quantity: mf.quantity
            ))
        }
        
        return ingredients
    }
}

