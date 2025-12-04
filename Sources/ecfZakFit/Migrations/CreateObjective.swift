//
//  CreateObjective.swift
//  ecfZakFit
//
//  Created by cyrilH on 26/11/2025.
//

import Fluent

struct CreateObjective: AsyncMigration {
    func prepare(on db: any Database) async throws {
        try await db.schema("objective")
            .id()
            .field("type", .string, .required)
            .field("value", .int, .required)
            .field("date", .datetime)
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .create()
    }

    func revert(on db: any Database) async throws {
        try await db.schema("objective").delete()
    }
}
