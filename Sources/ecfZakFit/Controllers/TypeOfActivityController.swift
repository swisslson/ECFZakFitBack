//
//  TypeOfActivity.swift
//  ecfZakFit
//
//  Created by cyrilH on 28/11/2025.
//

import Vapor
import Fluent

struct TypeOfActivityController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let types = routes.grouped("types-activity")
        
//        // Public routes
//        types.get("", use: getAll)
//        types.get(":typeID", use: getById)
//        
//        // Protected routes
//        let protected = types.grouped(JWTMiddleware())
//        protected.post(use: create)
//        protected.patch(":typeID", use: update)
//        protected.delete(":typeID", use: delete)
    }
    
    // MARK: - Handlers
    
//    func getAll(req: Request) throws -> EventLoopFuture<[TypeOfActivity]> {
//        TypeOfActivity.query(on: req.db).all()
//    }
//    
//    func getById(req: Request) throws -> EventLoopFuture<TypeOfActivity> {
//        TypeOfActivity.find(req.parameters.get("typeID"), on: req.db)
//            .unwrap(or: Abort(.notFound))
//    }
//    
//    func create(req: Request) throws -> EventLoopFuture<TypeOfActivity> {
//        let dto = try req.content.decode(CreateTypeOfActivityDTO.self)
//        let type = TypeOfActivity(nameOfActivity: dto.nameOfActivity)
//        return type.save(on: req.db).map { type }
//    }
//    
//    func update(req: Request) throws -> EventLoopFuture<TypeOfActivity> {
//        let dto = try req.content.decode(UpdateTypeOfActivityDTO.self)
//        return TypeOfActivity.find(req.parameters.get("typeID"), on: req.db)
//            .unwrap(or: Abort(.notFound))
//            .flatMap { type in
//                if let name = dto.nameOfActivity { type.nameOfActivity = name }
//                return type.save(on: req.db).map { type }
//            }
//    }
//    
//    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
//        TypeOfActivity.find(req.parameters.get("typeID"), on: req.db)
//            .unwrap(or: Abort(.notFound))
//            .flatMap { $0.delete(on: req.db) }
//            .transform(to: .ok)
//    }
}
