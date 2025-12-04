//
//  HystoryFilterDTO.swift
//  ecfZakFit
//
//  Created by cyrilH on 28/11/2025.
//

import Vapor

struct HistoryFilterDTO: Content {
    var period: String?
    var start: String?
    var end: String?
    var type: String?
}

struct HistoryResponse: Content {
    var activities: [AllActivityDTO] = []
    var meals: [AllMealDTO] = []
}



struct TotalsResponse: Content {
    var totalCaloriesBurned: Int
    var totalActivities: Int
    var totalMeals: Int
    var totalCaloriesConsumed: Double
    var totalProteins: Double
    var totalLipids: Double
    var totalCarbs: Double
}

struct StatsResponse: Content {
    var mostFrequentActivity: String?
    var mostFrequentActivityType: String?
    var mostFrequentMeal: String?
    var mostFrequentMealType: String?
}
