//
//  Users.swift
//  ecfZakFit
//
//  Created by cyrilH on 24/11/2025.
//
import Fluent
import Vapor

final class Users: Model,Content, @unchecked Sendable {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "lastName")
    var lastName: String
    
    @Field(key: "firstName")
    var firstName: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "passWord")
    var passWord: String
    
    @Field(key: "size")
    var size: Int?
    
    @Field(key: "weight")
    var weight: Int?
    
    @Field(key: "yearOfBirth")
    var yearOfBirth: Int?
    
    @OptionalEnum(key: "gender")
    var gender: UserGender?
    
    @Field(key: "frequencyOfActivity")
    var frequencyOfActivity: Int?
    
    @Field(key: "bmr")
    var bmr: Double?
    
    @OptionalEnum(key: "preferredFoodType")
    var preferredFoodType: UserTypePreferredPowerSupply?
    
    @OptionalEnum(key: "typeOfDailyActivity")
    var typeOfDailyActivity: UserTypeOfDailyActivity?
    
    @Field(key: "calorieDaily")
    var calorieDaily: Double?
    
    @Field(key: "proteinDaily")
    var proteinDaily: Double?
    
    @Field(key: "lipidDaily")
    var lipidDaily: Double?
    
    @Field(key: "carbohydrateDaily")
    var carbohydrateDaily: Double?
    
    @OptionalEnum(key: "objectivePersonal")
    var objectivePersonal: UserPersonalObjective?
    

    @Children(for : \.$user)
    var acivity: [Activity]
    
    @Children(for : \.$user)
    var meal: [Meal]
    
    @Children(for : \.$user)
    var food: [Food]
    
    @Children(for : \.$user)
    var objective: [Objective]
    
    
    
    init() {}
    init(
        id: UUID? = nil,
        lastName: String,
        firstName: String,
        email: String,
        passWord: String,
        size: Int? = nil,
        weight: Int? = nil,
        yearOfBirth: Int? = nil,
        gender: UserGender? = nil,
        frequencyOfActivity: Int? = nil,
        bmr: Double? = nil,
        preferredFoodType: UserTypePreferredPowerSupply? = nil,
        typeOfDailyActivity: UserTypeOfDailyActivity? = nil,
        calorieDaily: Double? = nil,
        proteinDaily: Double? = nil,
        lipidDaily: Double? = nil,
        carbohydrateDaily: Double? = nil,
        objectivePersonal: UserPersonalObjective? = nil
    ) {
        self.id = id ?? UUID()
        self.lastName = lastName
        self.firstName = firstName
        self.email = email
        self.passWord = passWord
        self.size = size
        self.weight = weight
        self.yearOfBirth = yearOfBirth
        self.gender = gender
        self.frequencyOfActivity = frequencyOfActivity
        self.bmr = bmr
        self.preferredFoodType = preferredFoodType
        self.typeOfDailyActivity = typeOfDailyActivity
        self.calorieDaily = calorieDaily
        self.proteinDaily = proteinDaily
        self.lipidDaily = lipidDaily
        self.carbohydrateDaily = carbohydrateDaily
        self.objectivePersonal = objectivePersonal
    }
    

}
