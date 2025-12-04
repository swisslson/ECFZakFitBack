//
//  Food.swift
//  ecfZakFit
//
//  Created by cyrilH on 25/11/2025.
//
import Fluent
import Vapor

final class Food : Model,Content, @unchecked Sendable {
    static let schema = "foods"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Enum(key: "category")
    var category: CategoryFood
    
    @Enum(key: "categoryPreference")
    var categoryPreference: UserTypePreferredPowerSupply
    
    @Field(key: "foodCalories")
    var foodCalories: Double
    
    @Field(key: "foodProteins")
    var foodProteins: Double
    
    @Field(key: "carbohydrateFromFood")
    var carbohydrateFromFood: Double
    
    @Field(key: "foodLipid")
    var foodLipide: Double
    
    @Field(key: "calculationUnit")
    var calculationUnit: Int
    
    @OptionalParent(key: "user_id")
    var user: Users?

    @Children(for : \.$food)
    var mealFood: [MealFood]
    
    init(){}
    init(
            id: UUID? = nil,
            name: String,
            category: CategoryFood,
            categoryPreference: UserTypePreferredPowerSupply,
            foodCalories: Double,
            foodProteins: Double,
            carbohydrateFromFood: Double,
            foodLipide: Double,
            calculationUnit: Int,
            userID: UUID? = nil
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.categoryPreference = categoryPreference
            self.foodCalories = foodCalories
            self.foodProteins = foodProteins
            self.carbohydrateFromFood = carbohydrateFromFood
            self.foodLipide = foodLipide
            self.calculationUnit = calculationUnit
            self.$user.id = userID
        }
}
