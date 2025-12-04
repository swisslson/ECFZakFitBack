//
//  typeOfActivity.swift
//  ecfZakFit
//
//  Created by cyrilH on 25/11/2025.
//

import Fluent
import Vapor

final class TypeOfActivity : Model,Content, @unchecked Sendable {
    static let schema = "typeOfActivity"
    
    @ID(key: .id)
    var id: UUID?
    
    @Enum(key: "nameOfActivity")
    var nameOfActivity: NameOfActivity
    
    @Children(for : \.$typeOfActivity)
    var acivity: [Activity]
    
    init(){}
    init(id: UUID? = nil, nameOfActivity: NameOfActivity) {
            self.id = id
            self.nameOfActivity = nameOfActivity
        }
}
