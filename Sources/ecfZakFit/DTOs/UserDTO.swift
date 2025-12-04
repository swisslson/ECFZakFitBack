//
//  UserDTO.swift
//  ecfZakFit
//
//  Created by cyrilH on 27/11/2025.
//

import Vapor

// MARK: - User DTOs
struct RegisterUserDTO: Content {
    let email: String
    var password: String
    let firstName: String
    let lastName: String
}

struct LoginUserDTO: Content {
    let email: String
    let password: String
}

struct UpdateBasicUserDTO: Content {
    var email: String?
    var password: String?
    var firstName: String?
    var lastName: String?
}

struct UpdatePersonalUserDTO: Content {
    var yearOfBirth: Int?
    var size: Int?
    var weight: Int?
    var gender: UserGender?
    var frequencyOfActivity: Int?
}

struct UpdatePreferencesDTO: Content {
    var preferredFoodType: UserTypePreferredPowerSupply?
}
struct UpdateBmrDTO: Content {
    var typeOfDailyActivity: UserTypeOfDailyActivity?
    var calorieDaily: Double?
    var proteinDaily: Double?
    var lipidDaily: Double?
    var carbohydrateDaily: Double?
    var objectivePersonal: UserPersonalObjective?
    var bmr: Double?

}

struct AllUserDTO: Content {
    let id: UUID?
    let email: String
    let firstName: String
    let lastName: String
    var yearOfBirth: Int?
    var size: Int?
    var weight: Int?
    var gender: UserGender?
    var frequencyOfActivity: Int?
    var preferredFoodType: UserTypePreferredPowerSupply?
    var bmr :Double?
    var typeOfDailyActivity: UserTypeOfDailyActivity?
    var calorieDaily: Double?
    var proteinDaily: Double?
    var lipidDaily: Double?
    var carbohydrateDaily: Double?
    var objectivePersonal: UserPersonalObjective?
}

