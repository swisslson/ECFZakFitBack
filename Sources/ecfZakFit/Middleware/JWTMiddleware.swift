//
//  JWTMiddleware.swift
//  ecfZakFit
//
//  Created by cyrilH on 27/11/2025.
//

import Vapor
import JWT

// MARK: - JWT Authentication Middleware
/// Middleware pour vérifier et valider les tokens JWT dans les requêtes HTTP
/// Ce middleware intercepte les requêtes protégées et vérifie la présence et la validité du token
final class JWTMiddleware: Middleware {
    
    // MARK: - Request Processing
    /// Intercepte la requête entrante, vérifie le token JWT, puis transmet la requête au prochain middleware
    /// - Parameters:
    ///   - request: La requête HTTP reçue
    ///   - next: Le prochain `Responder` dans la chaîne de traitement
    /// - Returns: Une future réponse HTTP, ou une erreur `401 Unauthorized` en cas d'échec
    func respond(to request: Request, chainingTo next: any Responder) -> EventLoopFuture<Response> {
        
        // MARK: - Extract JWT Token
        /// Extraction du token depuis le header "Authorization"
        /// Format attendu : `Authorization: Bearer <token>`
        guard let token = request.headers["Authorization"].first?.split(separator: " ").last else {
            return request.eventLoop.future(error: Abort(.unauthorized, reason: "Missing authentication token"))
        }
        
        // MARK: - JWT Verification
        /// Récupération de la clé secrète depuis les variables d'environnement
        guard let jwtSecret = Environment.get("JWT_SECRET") else {
            return request.eventLoop.future(error: Abort(.internalServerError, reason: "JWT secret not configured"))
        }
        
        /// Création du vérificateur JWT avec la clé secrète
        let signer = JWTSigner.hs256(key: jwtSecret)
        let payload: UserPayload
        
        do {
            // Vérification et décodage du token
            payload = try signer.verify(String(token), as: UserPayload.self)
        } catch {
            return request.eventLoop.future(error: Abort(.unauthorized, reason: "Invalid or expired token"))
        }
        
        // MARK: - Authenticate Request
        /// Si le token est valide, on attache le payload (utilisateur) à la requête
        request.auth.login(payload)
        
        // Transmission de la requête au middleware suivant
        return next.respond(to: request)
    }
}
