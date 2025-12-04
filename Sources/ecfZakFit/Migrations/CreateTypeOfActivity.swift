//
//  CreateTypeOfActivity.swift
//  ecfZakFit
//
//  Created by cyrilH on 26/11/2025.
//

import Fluent

struct CreateTypeOfActivity: AsyncMigration {
    func prepare(on db: any Database) async throws {
        try await db.schema("typeOfActivity")
            .id()
            .field("nameOfActivity", .string, .required)
            .create()
    }

    func revert(on db: any Database) async throws {
        try await db.schema("typeOfActivity").delete()
    }
}
