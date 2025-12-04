//
//  FoodDTO.swift
//  ecfZakFit
//
//  Created by cyrilH on 27/11/2025.
//

import Vapor

struct CreateFoodDTO: Content {
    let name: String
    let category: CategoryFood
    let categoryPreference: UserTypePreferredPowerSupply
    let foodCalories: Double
    let foodProteins: Double
    let carbohydrateFromFood: Double
    let foodLipid: Double
    let calculationUnit: Int
}

struct UpdateFoodDTO: Content {
    var name: String?
    var category: CategoryFood?
    var categoryPreference: UserTypePreferredPowerSupply?
    var foodCalories: Double?
    var foodProteins: Double?
    var carbohydrateFromFood: Double?
    var foodLipid: Double?
    var calculationUnit: Int?
}
struct AllFoodDTO: Content {
    let id: UUID?
    let name: String
    let category: CategoryFood
    let categoryPreference: UserTypePreferredPowerSupply
    let foodCalories: Double
    let foodProteins: Double
    let carbohydrateFromFood: Double
    let foodLipid: Double
    let calculationUnit: Int
}

