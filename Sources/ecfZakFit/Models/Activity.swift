//
//  Activity.swift
//  ecfZakFit
//
//  Created by cyrilH on 25/11/2025.
//

import Fluent
import Vapor

final class Activity : Model,Content, @unchecked Sendable {
    static let schema = "activities"
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "duration")
    var duration: Int?
    
    @Field(key: "caloriesBurned")
    var caloriesBurned: Int?
    
    @Field(key: "date")
    var date: Date?
    
    @Field(key: "name")
    var name: String
    
    @Parent(key: "user_id")
    var user: Users
    
    @Parent(key: "typeOfActivity_id")
    var typeOfActivity: TypeOfActivity
    
    
    
    init(){}
    init(
            id: UUID? = nil,
            duration: Int? = nil,
            caloriesBurned: Int? = nil,
            name: String,
            userID: UUID,
            typeOfActivityID: UUID
        ) {
            self.id = id
            self.duration = duration
            self.caloriesBurned = caloriesBurned
            self.name = name
            self.$user.id = userID
            self.$typeOfActivity.id = typeOfActivityID
            self.date = Date()
        }
    }
    

