//
//  objectiveDTO.swift
//  ecfZakFit
//
//  Created by cyrilH on 28/11/2025.
//

import Vapor

struct CreateObjectivesDTO: Content {
    var weight: Int?
    var activity: Int?
    var caloric: Int?
}

struct UpdateObjectivesDTO: Content {
    var weight: Int?
    var activity: Int?
    var caloric: Int?
}

struct ObjectiveDisplayDTO: Content {
    var id: UUID?
    var type: TypeOfObjective
    var value: Int
    var date: String? 
}
