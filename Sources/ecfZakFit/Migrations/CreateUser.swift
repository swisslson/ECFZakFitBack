//
//  CreateUser.swift
//  ecfZakFit
//
//  Created by cyrilH on 26/11/2025.
//
import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on db: any Database) async throws {
        try await db.schema("users")
            .id()
            .field("lastName", .string, .required)
            .field("firstName", .string, .required)
            .field("email", .string, .required)
            .field("passWord", .string, .required)
            .field("size", .int)
            .field("weight", .int)
            .field("yearOfBirth", .int)
            .field("gender", .string)
            .field("frequencyOfActivity", .int)
            .field("bmr", .double)
            .field("preferredFoodType", .string)
            .field("typeOfDailyActivity", .string)
            .field("calorieDaily", .double)
            .field("proteinDaily", .double)
            .field("lipidDaily", .double)
            .field("carbohydrateDaily", .double)
            .field("objectivePersonal", .string)
            .unique(on: "email")
            .create()
    }

    func revert(on db: any Database)  async throws {
       try await db.schema("users").delete()
    }
}
