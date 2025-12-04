//
//  CreateFood.swift
//  ecfZakFit
//
//  Created by cyrilH on 26/11/2025.
//

import Fluent

struct CreateFood: AsyncMigration {
    func prepare(on db: any Database) async throws {
        try await db.schema("foods")
            .id()
            .field("name", .string, .required)
            .field("category", .string, .required)
            .field("categoryPreference", .string, .required)
            .field("foodCalories", .double, .required)
            .field("foodProteins", .double, .required)
            .field("carbohydrateFromFood", .double, .required)
            .field("foodLipid", .double, .required)
            .field("calculationUnit", .int, .required)
            .field("user_id", .uuid, .references("users", "id", onDelete: .cascade))
            .create()
    }

    func revert(on db: any Database) async throws {
        try await db.schema("foods").delete()
    }
}

