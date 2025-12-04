//
//  CreateMeal.swift
//  ecfZakFit
//
//  Created by cyrilH on 26/11/2025.
//

import Fluent

struct CreateMeal: AsyncMigration {
    func prepare(on db: any Database) async throws {
        try await db.schema("meals")
            .id()
            .field("nameOfMeal", .string, .required)
            .field("date", .datetime)
            .field("totalcalories", .double, .required)
            .field("totalProtein", .double, .required)
            .field("totalLipid", .double, .required)
            .field("totalCarbohydrate", .double, .required)
            .field("typeOfMeal", .string, .required)
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .create()
    }

    func revert(on db: any Database) async throws {
        try await db.schema("meals").delete()
    }
}
