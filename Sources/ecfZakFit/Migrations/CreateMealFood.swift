//
//  CreateMealFood.swift
//  ecfZakFit
//
//  Created by cyrilH on 26/11/2025.
//
import Fluent

struct CreateMealFood: AsyncMigration {
    func prepare(on db: any Database) async throws {
        try await db.schema("mealsFoods")
            .id()
            .field("quantity", .int, .required)
            .field("meal_id", .uuid, .required, .references("meals", "id", onDelete: .cascade))
            .field("food_id", .uuid, .required, .references("foods", "id", onDelete: .cascade))
            .create()
    }
    
    func revert(on db: any Database) async throws {
        try await db.schema("mealsFoods").delete()
    }
}
