//
//  Meal.swift
//  ClaudeBugPoC
//

import Foundation

struct MealListResponse: Decodable {
    let meals: [MealListItem]?
}

struct MealListItem: Decodable {
    let id: String
    let name: String
    let thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case id = "idMeal"
        case name = "strMeal"
        case thumbnailURL = "strMealThumb"
    }
}
