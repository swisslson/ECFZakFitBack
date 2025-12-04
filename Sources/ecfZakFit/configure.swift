import NIOSSL
import Fluent
import FluentMySQLDriver
import Vapor
import FluentSQL
import Gatekeeper

// MARK: - Application Configuration
/// Configure tous les aspects de l'application Vapor : base de données, middleware, migrations, etc.
/// - Parameter app: L'instance de l'application Vapor à configurer
/// - Throws: Des erreurs si la configuration échoue (connexion DB, variables d'environnement manquantes, etc.)
public func configure(_ app: Application) async throws {
    
    // MARK: - Environment Variables Validation
    /// Validation des variables d'environnement critiques au démarrage
    /// Cela permet de détecter rapidement les problèmes de configuration
    guard let jwtSecret = Environment.get("JWT_SECRET"), !jwtSecret.isEmpty else {
        app.logger.critical("JWT_SECRET environment variable is missing or empty")
        fatalError("JWT_SECRET is required for authentication")
    }
    
    guard let databaseName = Environment.get("DATABASE_NAME"), !databaseName.isEmpty else {
        app.logger.critical("DATABASE_NAME environment variable is missing or empty")
        fatalError("DATABASE_NAME is required")
    }
    
    // Log des informations de démarrage (sans données sensibles)
    app.logger.info("Starting application in \(app.environment.name) mode")
    
    // MARK: - JSON Encoding/Decoding Configuration
    /// Configuration globale pour l'encodage et le décodage JSON
    /// Les dates sont gérées en secondes depuis 1970 (timestamp Unix)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    
    // Pretty printing uniquement en mode développement pour faciliter le debug
    if app.environment == .development {
        encoder.outputFormatting = .prettyPrinted
    }
    ContentConfiguration.global.use(encoder: encoder, for: .json)
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    ContentConfiguration.global.use(decoder: decoder, for: .json)
    
    // MARK: - Database Configuration
    /// Configuration de la connexion MySQL avec les paramètres depuis les variables d'environnement
    /// Utilise des valeurs par défaut seulement si les variables ne sont pas définies
    let databaseHost = Environment.get("DATABASE_HOST") ?? "localhost"
    let databasePort = Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 3306
    let databaseUsername = Environment.get("DATABASE_USERNAME") ?? "root"
    let databasePassword = Environment.get("DATABASE_PASSWORD") ?? ""
    
    app.databases.use(
        DatabaseConfigurationFactory.mysql(
            hostname: databaseHost,
            port: databasePort,
            username: databaseUsername,
            password: databasePassword,
            database: databaseName,
            tlsConfiguration: nil
        ),
        as: .mysql
    )
    
    app.logger.info(" Database configured: \(databaseUsername)@\(databaseHost):\(databasePort)/\(databaseName)")
    
    // MARK: - Middleware Configuration
    /// Configuration des middlewares dans l'ordre d'exécution
    /// L'ordre est important : CORS doit être avant l'authentification
    
    // 1. CORS Middleware - Autorise les requêtes cross-origin
    let corsMiddleware = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(corsMiddleware)
    app.logger.info("CORS middleware enabled")
    
    // 2. Rate Limiting avec Gatekeeper - Protection contre les abus
    app.caches.use(.memory) // Cache en mémoire pour stocker les compteurs de requêtes
    app.gatekeeper.config = .init(maxRequests: 100, per: .minute)
    app.middleware.use(GatekeeperMiddleware())
    app.logger.info("Rate limiting enabled: 100 requests/minute")
    
    // MARK: - Database Migrations
    /// Enregistrement de toutes les migrations dans l'ordre de dépendance
    /// L'ordre est crucial : les tables parentes doivent être créées avant les tables enfants
    app.migrations.add(CreateUser())              // Table users (parent)
    app.migrations.add(CreateTypeOfActivity())    // Table typeOfActivity (parent)
    app.migrations.add(CreateActivity())          // Table activities (enfant de users et typeOfActivity)
    app.migrations.add(CreateFood())              // Table foods (optionnellement lié à users)
    app.migrations.add(CreateMeal())              // Table meals (enfant de users)
    app.migrations.add(CreateMealFood())          // Table pivot mealsFoods (enfant de meals et foods)
    app.migrations.add(CreateObjective())         // Table objective (enfant de users)
    
    app.logger.info("Migrations registered: 7 tables")
    
    // Exécution automatique des migrations
    try await app.autoMigrate()
    app.logger.info("Database migrations completed successfully")
    
    // MARK: - Database Connection Test
    /// Test de connexion à la base de données au démarrage
    /// Utile pour détecter rapidement les problèmes de configuration
    if app.environment == .development {
        if let sql = app.db(.mysql) as? (any SQLDatabase) {
            do {
                _ = try await sql.raw("SELECT 1").all()
                app.logger.info("Database connection test successful")
            } catch {
                app.logger.error("Database connection test failed: \(error)")
            }
        }
    }
    app.jwt.signers.use(.hs256(key: jwtSecret))
    // MARK: - Routes Registration
    /// Enregistrement de toutes les routes de l'application
    try routes(app)
    app.logger.info("Routes registered successfully")
    
    // Log final
    app.logger.info("Application configuration completed")
}
