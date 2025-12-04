//
//  ActivityDTO.swift
//  ecfZakFit
//
//  Created by cyrilH on 28/11/2025.
//
import Vapor

struct CreateActivityDTO: Content {
    let type: UUID
    let duration: Int
    let caloriesBurned: Int
    let name: String
}

struct UpdateActivityDTO: Content {
    var typeOfActivityID: UUID?
    var duration: Int?
    var caloriesBurned: Int?
    var name: String?
}
struct AllActivityDTO: Content {
    let id: UUID?
    let type: TypeOfActivityDTO
    let duration: Int?
    let caloriesBurned: Int?
    let name: String?
    let date: Date?
}

