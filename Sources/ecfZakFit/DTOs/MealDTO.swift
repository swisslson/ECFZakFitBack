//
//  MealDTO.swift
//  ecfZakFit
//
//  Created by cyrilH on 28/11/2025.
//
import Vapor

struct CreateMealDTO: Content {
    let nameOfMeal: String
    let typeOfMeal: TypeOfMeal
    let ingredients: [MealIngredientCreateDTO]
}

struct MealIngredientDTO: Content {
    let foodID: UUID
    let name: String
    let quantity: Int
}
struct MealIngredientCreateDTO: Content {
    let foodID: UUID
    let quantity: Int
}
struct UpdateMealDTO: Content {
    var nameOfMeal: String?
    var typeOfMeal: TypeOfMeal?
    var ingredients: [MealIngredientUpdateDTO]?
}
struct MealIngredientUpdateDTO: Content {
    let foodID: UUID
    let quantity: Int
}

struct AllMealDTO: Content {
    let id: UUID?
    let nameOfMeal: String
    let typeOfMeal: TypeOfMeal
    let ingredients: [MealIngredientDTO]
    let totalcalories: Double
    let totalProtein: Double
    let totalLipid: Double
    let totalCarbohydrate: Double
    var date: Date
}


