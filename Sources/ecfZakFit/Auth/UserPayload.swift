//
//  UserPayload.swift
//  ecfZakFit
//
//  Created by cyrilH on 27/11/2025.
//
import Foundation
import Vapor
import JWT

// MARK: - JWT Payload
/// Représente les informations contenues dans un token JWT pour l'authentification d'un utilisateur
/// Ce payload est utilisé par le middleware `JWTMiddleware` pour vérifier l'identité de l'utilisateur
struct UserPayload: JWTPayload, Authenticatable {
    
    /// Identifiant unique de l'utilisateur
    var id: UUID
    
    /// Date d'expiration du token
    var expiration: Date
    
    // MARK: - Token Verification
    /// Vérifie que le token JWT n'a pas expiré
    /// - Parameter signer: Le `JWTSigner` utilisé pour valider la signature du token
    /// - Throws: `Abort(.unauthorized)` si la date d'expiration est dépassée
    func verify(using signer: JWTSigner) throws {
        guard expiration > Date() else {
            throw Abort(.unauthorized, reason: "Token expired")
        }
    }
    
    // MARK: - Initialization
    /// Initialise un nouveau payload JWT pour un utilisateur
    /// - Parameter id: L'identifiant unique de l'utilisateur
    /// - Note: La date d'expiration est automatiquement fixée à 24 heures après la création
    init(id: UUID) {
        self.id = id
        self.expiration = Date().addingTimeInterval(3600 * 24) // 24 heures
    }
}
