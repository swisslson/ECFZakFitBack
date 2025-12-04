//
//  MealFood.swift
//  ecfZakFit
//
//  Created by cyrilH on 25/11/2025.
//

import Fluent
import Vapor

final class MealFood : Model,Content, @unchecked Sendable {
    static let schema = "mealsFoods"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "quantity")
    var quantity : Int
    
    @Parent(key: "meal_id")
    var meal: Meal
    
    @Parent(key: "food_id")
    var food: Food
    
    init(){}
    init(id: UUID? = nil, quantity: Int, mealID: UUID, foodID: UUID) {
            self.id = id
            self.quantity = quantity
            self.$meal.id = mealID
            self.$food.id = foodID
        }
}
