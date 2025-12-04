//
//  meal.swift
//  ecfZakFit
//
//  Created by cyrilH on 25/11/2025.
//

import Fluent
import Vapor

final class Meal : Model,Content, @unchecked Sendable {
    static let schema = "meals"
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "nameOfMeal")
    var nameOfMeal: String
    
    @Field(key: "date")
    var date: Date?
    
    @Field(key: "totalcalories")
    var totalcalories: Double
    
    @Field(key: "totalProtein")
    var totalProtein: Double
    
    @Field(key: "totalLipid")
    var totalLipid: Double
    
    @Field(key: "totalCarbohydrate")
    var totalCarbohydrate: Double
    
    @Enum(key: "typeOfMeal")
    var typeOfMeal: TypeOfMeal

    @Parent(key: "user_id")
    var user: Users
    
    @Children(for : \.$meal)
    var mealFoods: [MealFood]
    
    init(){}
    init(
            id: UUID? = nil,
            nameOfMeal: String,
            totalcalories: Double,
            totalProtein: Double,
            totalLipid: Double,
            totalCarbohydrate: Double,
            typeOfMeal: TypeOfMeal,
            userID: UUID
        ) {
            self.id = id
            self.nameOfMeal = nameOfMeal
            self.totalcalories = totalcalories
            self.totalProtein = totalProtein
            self.totalLipid = totalLipid
            self.totalCarbohydrate = totalCarbohydrate
            self.typeOfMeal = typeOfMeal
            self.$user.id = userID
            self.date = Date()
        }
}
