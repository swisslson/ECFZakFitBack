//
//  CreateActivity.swift
//  ecfZakFit
//
//  Created by cyrilH on 26/11/2025.
//

import Fluent

struct CreateActivity: AsyncMigration {
    func prepare(on db: any Database) async throws {
        try await db.schema("activities")
            .id()
            .field("duration", .int)
            .field("caloriesBurned", .int)
            .field("date", .datetime)
            .field("name", .string, .required)
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("typeOfActivity_id", .uuid, .required, .references("typeOfActivity", "id", onDelete: .cascade))
            .create()
    }

    func revert(on db: any Database) async throws {
        try await db.schema("activities").delete()
    }
}
