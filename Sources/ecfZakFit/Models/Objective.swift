//
//  Objective.swift
//  ecfZakFit
//
//  Created by cyrilH on 25/11/2025.
//
import Fluent
import Vapor

final class Objective : Model,Content, @unchecked Sendable {
    static let schema = "objective"
    
    @ID(key: .id)
    var id: UUID?
    
    @Enum(key: "type")
    var type: TypeOfObjective
    
    @Field(key: "value")
    var value: Int
    
    @Timestamp(key: "date", on: .create)
    var date: Date?
    
    @Parent(key: "user_id")
    var user: Users
    
    init(){}
    
    init(
            id: UUID? = nil,
            type: TypeOfObjective,
            value: Int,
            userID: UUID
        ) {
            self.id = id
            self.type = type
            self.value = value
            self.$user.id = userID
        }
    
}

