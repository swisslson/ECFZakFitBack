//
//  HistoryController.swift
//  ecfZakFit
//
//  Created by cyrilH on 28/11/2025.
//

import Vapor
import Fluent

// MARK: - History Controller
/// Contrôleur gérant l'historique des activités et repas des utilisateurs
/// Fournit des vues agrégées, des totaux et des statistiques
struct HistoryController: RouteCollection {
    
    // MARK: - Routes Configuration
    /// Configure toutes les routes liées à l'historique
    /// - Parameter routes: Le constructeur de routes Vapor
    func boot(routes: any RoutesBuilder) throws {
        let history = routes.grouped("history").grouped(JWTMiddleware())
        
        history.get("", use: getHistory)           // GET /history - Historique filtré
        history.get("totals", use: getTotals)      // GET /history/totals - Totaux agrégés
        history.get("stats", use: getStats)        // GET /history/stats - Statistiques
    }
    
    // MARK: - GET /history
    /// Récupère l'historique filtré des activités et repas de l'utilisateur
    ///
    /// Query parameters disponibles :
    /// - `period` : Période prédéfinie ("day" | "week" | "month")
    /// - `start` : Date de début au format yyyy-MM-dd
    /// - `end` : Date de fin au format yyyy-MM-dd
    /// - `type` : Type de données ("activity" | "meal" | "both")
    ///
    /// - Parameter req: La requête HTTP avec les query parameters et le token JWT
    /// - Returns: Un `HistoryResponse` contenant les activités et repas filtrés
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    func getHistory(req: Request) async throws -> HistoryResponse {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        let calendar = Calendar.current
        
        // Lecture des paramètres de filtrage
        let period = req.query[String.self, at: "period"]
        let startStr = req.query[String.self, at: "start"]
        let endStr = req.query[String.self, at: "end"]
        let typeFilter = req.query[String.self, at: "type"]
        
        // MARK: Calcul de la plage de dates
        let startDate: Date
        let endDate: Date
        
        if let s = startStr?.toDate(), let e = endStr?.toDate() {
            // Plage personnalisée fournie par l'utilisateur
            startDate = s
            endDate = calendar.endOfDay(for: e)
        } else {
            // Plage basée sur la période prédéfinie
            let now = Date()
            switch period {
            case "week", nil:
                startDate = calendar.startOfWeek(for: now)
                endDate = calendar.endOfWeek(for: now)
            case "month":
                startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                endDate = calendar.endOfMonth(for: now)
            case "day":
                startDate = calendar.startOfDay(for: now)
                endDate = calendar.endOfDay(for: now)
            default:
                startDate = calendar.startOfDay(for: now)
                endDate = calendar.endOfDay(for: now)
            }
        }
        
        // MARK: Chargement des activités
        var activityDTOs: [AllActivityDTO] = []
        if typeFilter == "activity" || typeFilter == "both" || typeFilter == nil {
            let activities = try await Activity.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$date >= startDate)
                .filter(\.$date <= endDate)
                .with(\.$typeOfActivity)
                .sort(\.$date, .descending)
                .all()
            
            activityDTOs = activities.map { activity in
                AllActivityDTO(
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
        }
        
        // MARK: Chargement des repas avec leurs ingrédients
        var mealDTOs: [AllMealDTO] = []
        if typeFilter == "meal" || typeFilter == "both" || typeFilter == nil {
            let meals = try await Meal.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$date >= startDate)
                .filter(\.$date <= endDate)
                .with(\.$mealFoods) { mealFood in
                    mealFood.with(\.$food)
                }
                .sort(\.$date, .descending)
                .all()
            
            for meal in meals {
                // Construction des ingrédients à partir de mealFoods
                let ingredientDTOs = meal.mealFoods.map { mealFood in
                    MealIngredientDTO(
                        foodID: mealFood.food.id ?? UUID(),
                        name: mealFood.food.name,
                        quantity: mealFood.quantity
                    )
                }
                
                let dto = AllMealDTO(
                    id: meal.id,
                    nameOfMeal: meal.nameOfMeal,
                    typeOfMeal: meal.typeOfMeal,
                    ingredients: ingredientDTOs,
                    totalcalories: meal.totalcalories,
                    totalProtein: meal.totalProtein,
                    totalLipid: meal.totalLipid,
                    totalCarbohydrate: meal.totalCarbohydrate,
                    date: meal.date ?? Date()
                )
                
                mealDTOs.append(dto)
            }
        }
        
        return HistoryResponse(activities: activityDTOs, meals: mealDTOs)
    }
    
    // MARK: - GET /history/totals
    /// Calcule les totaux agrégés pour une période donnée
    ///
    /// Query parameters disponibles :
    /// - `period` : Période prédéfinie ("day" | "week" | "month", défaut: "week")
    /// - `start` : Date de début au format yyyy-MM-dd
    /// - `end` : Date de fin au format yyyy-MM-dd
    /// - `type` : Type de données ("activity" | "meal" | "both")
    ///
    /// - Parameter req: La requête HTTP avec les query parameters et le token JWT
    /// - Returns: Un `TotalsResponse` contenant les totaux agrégés
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    func getTotals(req: Request) async throws -> TotalsResponse {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        // Lecture des paramètres
        let period = req.query[String.self, at: "period"] ?? "week"
        let startStr = req.query[String.self, at: "start"]
        let endStr = req.query[String.self, at: "end"]
        let typeFilter = req.query[String.self, at: "type"]
        
        let now = Date()
        let calendar = Calendar.current
        
        // MARK: Calcul de la plage de dates
        let startDate: Date
        let endDate: Date
        
        if let s = startStr?.toDate(), let e = endStr?.toDate() {
            startDate = s
            endDate = calendar.endOfDay(for: e)
        } else {
            switch period {
            case "week":
                startDate = calendar.startOfWeek(for: now)
                endDate = calendar.endOfWeek(for: now)
            case "month":
                startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                endDate = calendar.endOfMonth(for: now)
            case "day":
                startDate = calendar.startOfDay(for: now)
                endDate = calendar.endOfDay(for: now)
            default:
                startDate = calendar.startOfDay(for: now)
                endDate = now
            }
        }
        
        // MARK: Chargement des activités
        var activities: [Activity] = []
        if typeFilter == "activity" || typeFilter == "both" || typeFilter == nil {
            activities = try await Activity.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$date >= startDate)
                .filter(\.$date <= endDate)
                .all()
        }
        
        // MARK: Chargement des repas
        var meals: [Meal] = []
        if typeFilter == "meal" || typeFilter == "both" || typeFilter == nil {
            meals = try await Meal.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$date >= startDate)
                .filter(\.$date <= endDate)
                .all()
        }
        
        // MARK: Calcul des totaux pour les activités
        var totalCaloriesBurned: Int = 0
        let totalActivities: Int = activities.count
        
        for activity in activities {
            totalCaloriesBurned += activity.caloriesBurned ?? 0
        }
        
        // MARK: Calcul des totaux pour les repas
        let totalMeals: Int = meals.count
        var totalCaloriesConsumed: Double = 0
        var totalProteins: Double = 0
        var totalLipids: Double = 0
        var totalCarbs: Double = 0
        
        for meal in meals {
            totalCaloriesConsumed += meal.totalcalories
            totalProteins += meal.totalProtein
            totalLipids += meal.totalLipid
            totalCarbs += meal.totalCarbohydrate
        }
        
        return TotalsResponse(
            totalCaloriesBurned: totalCaloriesBurned,
            totalActivities: totalActivities,
            totalMeals: totalMeals,
            totalCaloriesConsumed: totalCaloriesConsumed,
            totalProteins: totalProteins,
            totalLipids: totalLipids,
            totalCarbs: totalCarbs
        )
    }
    
    // MARK: - GET /history/stats
    /// Calcule des statistiques sur les habitudes de l'utilisateur
    /// Identifie les activités et repas les plus fréquents
    ///
    /// - Parameter req: La requête HTTP avec le token JWT
    /// - Returns: Un `StatsResponse` contenant les statistiques
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    func getStats(req: Request) async throws -> StatsResponse {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        let userID = try user.requireID()
        
        // Chargement de toutes les activités de l'utilisateur
        let activities = try await Activity.query(on: req.db)
            .filter(\.$user.$id == userID)
            .with(\.$typeOfActivity)
            .all()
        
        // Chargement de tous les repas de l'utilisateur
        let meals = try await Meal.query(on: req.db)
            .filter(\.$user.$id == userID)
            .all()
        
        // MARK: Calcul de l'activité la plus fréquente
        // Groupement par nom d'activité
        let activityGroups = Dictionary(grouping: activities, by: { $0.name })
        // Recherche du groupe le plus nombreux
        let mostFrequentActivityEntry = activityGroups.max(by: { $0.value.count < $1.value.count })?.value.first
        
        // MARK: Calcul du repas le plus fréquent
        // Groupement par nom de repas
        let mealGroups = Dictionary(grouping: meals, by: { $0.nameOfMeal })
        // Recherche du groupe le plus nombreux
        let mostFrequentMealEntry = mealGroups.max(by: { $0.value.count < $1.value.count })?.value.first
        
        return StatsResponse(
            mostFrequentActivity: mostFrequentActivityEntry?.name,
            mostFrequentActivityType: mostFrequentActivityEntry?.typeOfActivity.nameOfActivity.rawValue,
            mostFrequentMeal: mostFrequentMealEntry?.nameOfMeal,
            mostFrequentMealType: mostFrequentMealEntry?.typeOfMeal.rawValue
        )
    }
}
