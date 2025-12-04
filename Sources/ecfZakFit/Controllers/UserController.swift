//
//  UserController.swift
//  ecfZakFit
//
//  Created by cyrilH on 27/11/2025.
//
import Fluent
import Vapor
import JWT

// MARK: - User Controller
/// Contrôleur gérant l'authentification et la gestion des profils utilisateurs
/// Gère l'inscription, la connexion, la consultation et la mise à jour des profils
struct UserController: RouteCollection {
    
    // MARK: - Routes Configuration
    /// Configure toutes les routes liées aux utilisateurs
    /// - Parameter routes: Le constructeur de routes Vapor
    func boot(routes: any RoutesBuilder) throws {
        let users = routes.grouped("users")
        
        // Routes publiques (sans authentification)
        users.post(use: create)                    // POST /users - Inscription
        users.post("login", use: login)            // POST /users/login - Connexion
        users.get("", use: getAll)                 // GET /users - Liste des utilisateurs (admin)
        
        // Routes protégées par JWT
        let protectedUsersRoutes = users.grouped(JWTMiddleware())
        
        protectedUsersRoutes.get("profile", use: profile)                                  // GET /users/profile
        protectedUsersRoutes.patch("profile", use: updateProfile)                          // PATCH /users/profile
        protectedUsersRoutes.patch("profile", "personal", use: updateProfilePersonal)      // PATCH /users/profile/personal
        protectedUsersRoutes.patch("profile", "preferedFoodType", use: updateProfilePreferredFoodType)  // PATCH /users/profile/preferedFoodType
        protectedUsersRoutes.patch("profile", "bmr", use: updateProfileBmr)               // PATCH /users/profile/bmr
        
        // Routes avec paramètre :userID
        users.group(":userID") { user in
            user.get(use: getById)                 // GET /users/:userID
            user.delete(use: delete)               // DELETE /users/:userID
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Convertit un modèle `Users` en `AllUserDTO` complet
    /// Centralise la logique de transformation pour éviter la duplication
    /// - Parameter user: L'utilisateur à convertir
    /// - Returns: Un `AllUserDTO` représentant l'utilisateur
    /// - Note: Utilisée dans profile(), updateProfile(), updateProfilePersonal(), updateProfilePreferredFoodType(), updateProfileBmr()
    private func userToCompleteDTO(_ user: Users) -> AllUserDTO {
        return AllUserDTO(
            id: user.id,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            yearOfBirth: user.yearOfBirth,
            size: user.size,
            weight: user.weight,
            gender: user.gender,
            frequencyOfActivity: user.frequencyOfActivity,
            preferredFoodType: user.preferredFoodType,
            bmr: user.bmr,
            typeOfDailyActivity: user.typeOfDailyActivity,
            calorieDaily: user.calorieDaily,
            proteinDaily: user.proteinDaily,
            lipidDaily: user.lipidDaily,
            carbohydrateDaily: user.carbohydrateDaily,
            objectivePersonal: user.objectivePersonal
        )
    }
    
    // MARK: - POST /users
    /// Crée un nouveau compte utilisateur (inscription)
    ///
    /// - Parameter req: La requête HTTP contenant le DTO d'inscription
    /// - Returns: Un `AllUserDTO` représentant l'utilisateur créé (sans données sensibles)
    /// - Throws:
    ///   - `Abort(.conflict)` si l'email est déjà utilisé
    ///   - Erreurs de hachage si le mot de passe ne peut pas être sécurisé
    /// - Note: Le mot de passe est automatiquement haché avec Bcrypt avant stockage
    func create(req: Request) async throws -> AllUserDTO {
        var dto = try req.content.decode(RegisterUserDTO.self)
        
        // MARK: Hachage du mot de passe
        // Utilisation de Bcrypt pour sécuriser le mot de passe avant stockage
        dto.password = try Bcrypt.hash(dto.password)
        
        // MARK: Vérification de l'unicité de l'email
        let existingUser = try await Users.query(on: req.db)
            .filter(\.$email == dto.email)
            .first()
        
        if existingUser != nil {
            throw Abort(.conflict, reason: "This email is already in use")
        }
        
        // MARK: Création de l'utilisateur
        let user = Users(
            lastName: dto.lastName,
            firstName: dto.firstName,
            email: dto.email,
            passWord: dto.password
        )
        
        try await user.save(on: req.db)
        
        // Retour d'un DTO minimal (sans informations sensibles)
        return AllUserDTO(
            id: user.id,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName
        )
    }
    
    // MARK: - POST /users/login
    /// Authentifie un utilisateur et génère un token JWT
    ///
    /// - Parameter req: La requête HTTP contenant les identifiants de connexion
    /// - Returns: Un `LoginResponse` contenant le token JWT
    /// - Throws:
    ///   - `Abort(.unauthorized)` si l'email n'existe pas ou le mot de passe est incorrect
    ///   - Erreurs JWT si la génération du token échoue
    /// - Note: Le token JWT est valide pendant 24 heures
    func login(req: Request) async throws -> LoginResponse {
        let userData = try req.content.decode(LoginUserDTO.self)
        
        // MARK: Vérification de l'existence de l'utilisateur
        guard let user = try await Users.query(on: req.db)
            .filter(\.$email == userData.email)
            .first() else {
            throw Abort(.unauthorized, reason: "User does not exist")
        }
        
        // MARK: Vérification du mot de passe
        // Utilise Bcrypt.verify pour comparer le mot de passe fourni avec le hash stocké
        guard try Bcrypt.verify(userData.password, created: user.passWord) else {
            throw Abort(.unauthorized, reason: "Incorrect password")
        }
        
        // MARK: Génération du token JWT
        let payload = UserPayload(id: user.id!)
        let token = try req.application.jwt.signers.sign(payload)
        
        return LoginResponse(token: token)
    }
    
    // MARK: - GET /users
    /// Récupère la liste de tous les utilisateurs (vue simplifiée)
    ///
    /// - Parameter req: La requête HTTP
    /// - Returns: Un tableau de `AllUserDTO` avec les informations basiques
    /// - Note: Cette route devrait être protégée en production (admin uniquement)
    /// - Warning: Retourne tous les utilisateurs sans pagination, à optimiser pour la production
    func getAll(req: Request) async throws -> [AllUserDTO] {
        let users = try await Users.query(on: req.db).all()
        
        return users.map { user in
            AllUserDTO(
                id: user.id,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName
            )
        }
    }
    
    // MARK: - GET /users/:userID
    /// Récupère un utilisateur spécifique par son ID (vue simplifiée)
    ///
    /// - Parameter req: La requête HTTP contenant l'ID dans les paramètres
    /// - Returns: Un `AllUserDTO` avec les informations basiques
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    /// - Note: Cette route devrait vérifier les permissions en production
    func getById(req: Request) async throws -> AllUserDTO {
        guard let user = try await Users.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        return AllUserDTO(
            id: user.id,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName
        )
    }
    
    // MARK: - DELETE /users/:userID
    /// Supprime un compte utilisateur
    ///
    /// - Parameter req: La requête HTTP contenant l'ID de l'utilisateur
    /// - Returns: Un statut HTTP `.noContent` (204) en cas de succès
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    /// - Warning: La suppression en cascade supprimera toutes les données liées (activités, repas, objectifs)
    /// - Note: Cette route devrait vérifier les permissions en production
    func delete(req: Request) async throws -> HTTPStatus {
        guard let user = try await Users.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        try await user.delete(on: req.db)
        return .noContent
    }
    
    // MARK: - GET /users/profile
    /// Récupère le profil complet de l'utilisateur authentifié
    ///
    /// - Parameter req: La requête HTTP avec le token JWT
    /// - Returns: Un `AllUserDTO` complet avec toutes les informations du profil
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    func profile(req: Request) async throws -> AllUserDTO {
        // Récupération de l'utilisateur depuis le token JWT
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        return userToCompleteDTO(user)
    }
    
    // MARK: - PATCH /users/profile
    /// Met à jour les informations basiques du profil (nom, prénom, email, mot de passe)
    ///
    /// - Parameter req: La requête HTTP contenant le DTO de mise à jour et le token JWT
    /// - Returns: Un `AllUserDTO` complet avec les informations mises à jour
    /// - Throws:
    ///   - `Abort(.notFound)` si l'utilisateur n'existe pas
    ///   - `Abort(.conflict)` si le nouvel email est déjà utilisé par un autre compte
    /// - Note: Tous les champs du DTO sont optionnels, seuls les champs fournis sont mis à jour
    func updateProfile(req: Request) async throws -> AllUserDTO {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        let dto = try req.content.decode(UpdateBasicUserDTO.self)
        
        // MARK: Mise à jour du prénom
        if let firstName = dto.firstName {
            user.firstName = firstName
        }
        
        // MARK: Mise à jour du nom
        if let lastName = dto.lastName {
            user.lastName = lastName
        }
        
        // MARK: Mise à jour de l'email (avec vérification d'unicité)
        if let email = dto.email {
            if email != user.email {
                // Vérification que le nouvel email n'est pas déjà utilisé
                let existingUser = try await Users.query(on: req.db)
                    .filter(\.$email == email)
                    .first()
                
                if existingUser != nil {
                    throw Abort(.conflict, reason: "This email is already in use by another account")
                }
                user.email = email
            }
        }
        
        // MARK: Mise à jour du mot de passe (avec hachage)
        if let password = dto.password {
            user.passWord = try Bcrypt.hash(password)
        }
        
        try await user.save(on: req.db)
        
        return userToCompleteDTO(user)
    }
    
    // MARK: - PATCH /users/profile/personal
    /// Met à jour les informations personnelles (année de naissance, taille, poids, genre, fréquence d'activité)
    ///
    /// - Parameter req: La requête HTTP contenant le DTO de mise à jour et le token JWT
    /// - Returns: Un `AllUserDTO` complet avec les informations mises à jour
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    /// - Note: Tous les champs du DTO sont optionnels, seuls les champs fournis sont mis à jour
    func updateProfilePersonal(req: Request) async throws -> AllUserDTO {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        let dto = try req.content.decode(UpdatePersonalUserDTO.self)
        
        // Mise à jour conditionnelle des champs personnels
        if let year = dto.yearOfBirth {
            user.yearOfBirth = year
        }
        
        if let size = dto.size {
            user.size = size
        }
        
        if let weight = dto.weight {
            user.weight = weight
        }
        
        if let gender = dto.gender {
            user.gender = gender
        }
        
        if let frequence = dto.frequencyOfActivity {
            user.frequencyOfActivity = frequence
        }
        
        try await user.save(on: req.db)
        
        return userToCompleteDTO(user)
    }
    
    // MARK: - PATCH /users/profile/preferedFoodType
    /// Met à jour les préférences alimentaires de l'utilisateur
    ///
    /// - Parameter req: La requête HTTP contenant le DTO de mise à jour et le token JWT
    /// - Returns: Un `AllUserDTO` complet avec les informations mises à jour
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    /// - Note: Permet de définir le régime alimentaire (végétarien, vegan, flexitarien, pescétarien)
    func updateProfilePreferredFoodType(req: Request) async throws -> AllUserDTO {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        let dto = try req.content.decode(UpdatePreferencesDTO.self)
        
        if let preferredFoodType = dto.preferredFoodType {
            user.preferredFoodType = preferredFoodType
        }
        
        try await user.save(on: req.db)
        
        return userToCompleteDTO(user)
    }
    
    // MARK: - PATCH /users/profile/bmr
    /// Met à jour les données liées au métabolisme de base (BMR) et aux objectifs nutritionnels
    ///
    /// - Parameter req: La requête HTTP contenant le DTO de mise à jour et le token JWT
    /// - Returns: Un `AllUserDTO` complet avec les informations mises à jour
    /// - Throws: `Abort(.notFound)` si l'utilisateur n'existe pas
    /// - Note: Le BMR (Basal Metabolic Rate) et les besoins quotidiens en macronutriments
    func updateProfileBmr(req: Request) async throws -> AllUserDTO {
        // Récupération de l'utilisateur authentifié
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await Users.find(payload.id, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        let dto = try req.content.decode(UpdateBmrDTO.self)
        
        // Mise à jour conditionnelle des données métaboliques
        if let typeOfDailyActivity = dto.typeOfDailyActivity {
            user.typeOfDailyActivity = typeOfDailyActivity
        }
        
        if let calorieDaily = dto.calorieDaily {
            user.calorieDaily = calorieDaily
        }
        
        if let proteinDaily = dto.proteinDaily {
            user.proteinDaily = proteinDaily
        }
        
        if let lipidDaily = dto.lipidDaily {
            user.lipidDaily = lipidDaily
        }
        
        if let carbohydrateDaily = dto.carbohydrateDaily {
            user.carbohydrateDaily = carbohydrateDaily
        }
        
        if let objectivePersonal = dto.objectivePersonal {
            user.objectivePersonal = objectivePersonal
        }
        
        if let bmr = dto.bmr {
            user.bmr = bmr
        }
        
        try await user.save(on: req.db)
        
        return userToCompleteDTO(user)
    }
    
    // MARK: - Response DTOs
    
    /// Structure de réponse pour la connexion
    /// Contient uniquement le token JWT
    struct LoginResponse: Content {
        let token: String
    }
}
