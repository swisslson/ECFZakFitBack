//
//  CORSMiddleware.swift
//  ecfZakFit
//
//  Created by cyrilH on 27/11/2025.
//

import Vapor

// MARK: - CORS Configuration
/// Configuration CORS (Cross-Origin Resource Sharing) pour autoriser les requêtes depuis d'autres domaines
/// Cette configuration est particulièrement importante pour les applications avec frontend séparé
/// Configuration CORS permettant toutes les origines en développement
let corsConfiguration = CORSMiddleware.Configuration(
    // Origines autorisées
    // .all permet toutes les origines (à restreindre en production)
    // Exemple production : .custom(["https://monapp.com", "https://www.monapp.com"])
    allowedOrigin: .all,
    
    // Méthodes HTTP autorisées pour les requêtes cross-origin
    allowedMethods: [
        .GET,      // Lecture de données
        .POST,     // Création de ressources
        .PUT,      // Remplacement complet d'une ressource
        .PATCH,    // Mise à jour partielle d'une ressource
        .DELETE,   // Suppression de ressources
        .OPTIONS   // Preflight request (requis pour CORS)
    ],
    
    // En-têtes HTTP autorisés dans les requêtes
    allowedHeaders: [
        .accept,          // Type de contenu accepté en réponse
        .authorization,   // Token JWT pour l'authentification
        .contentType,     // Type de contenu envoyé (ex: application/json)
        .origin,          // Origine de la requête
        .xRequestedWith   // Header pour identifier les requêtes AJAX
    ],
    
    // Durée de mise en cache de la configuration CORS côté client (en secondes)
    // 800 secondes = ~13 minutes
    cacheExpiration: 800
)
