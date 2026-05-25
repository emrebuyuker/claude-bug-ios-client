//
//  MealDetail.swift
//  ClaudeBugPoC
//

import Foundation

struct MealDetailResponse: Decodable {
    let meals: [MealDetail]?
}

struct MealDetail: Decodable {
    let id: String
    let name: String
    let category: String?
    let area: String?
    let instructions: String?
    let thumbnailURL: String?
    let tags: String?
    let youtubeURL: String?
    let sourceURL: String?

    private let strIngredient1: String?
    private let strIngredient2: String?
    private let strIngredient3: String?
    private let strIngredient4: String?
    private let strIngredient5: String?
    private let strIngredient6: String?
    private let strIngredient7: String?
    private let strIngredient8: String?
    private let strIngredient9: String?
    private let strIngredient10: String?
    private let strIngredient11: String?
    private let strIngredient12: String?
    private let strIngredient13: String?
    private let strIngredient14: String?
    private let strIngredient15: String?
    private let strIngredient16: String?
    private let strIngredient17: String?
    private let strIngredient18: String?
    private let strIngredient19: String?
    private let strIngredient20: String?

    private let strMeasure1: String?
    private let strMeasure2: String?
    private let strMeasure3: String?
    private let strMeasure4: String?
    private let strMeasure5: String?
    private let strMeasure6: String?
    private let strMeasure7: String?
    private let strMeasure8: String?
    private let strMeasure9: String?
    private let strMeasure10: String?
    private let strMeasure11: String?
    private let strMeasure12: String?
    private let strMeasure13: String?
    private let strMeasure14: String?
    private let strMeasure15: String?
    private let strMeasure16: String?
    private let strMeasure17: String?
    private let strMeasure18: String?
    private let strMeasure19: String?
    private let strMeasure20: String?

    enum CodingKeys: String, CodingKey {
        case id = "idMeal"
        case name = "strMeal"
        case category = "strCategory"
        case area = "strArea"
        case instructions = "strInstructions"
        case thumbnailURL = "strMealThumb"
        case tags = "strTags"
        case youtubeURL = "strYoutube"
        case sourceURL = "strSource"
        case strIngredient1, strIngredient2, strIngredient3, strIngredient4, strIngredient5
        case strIngredient6, strIngredient7, strIngredient8, strIngredient9, strIngredient10
        case strIngredient11, strIngredient12, strIngredient13, strIngredient14, strIngredient15
        case strIngredient16, strIngredient17, strIngredient18, strIngredient19, strIngredient20
        case strMeasure1, strMeasure2, strMeasure3, strMeasure4, strMeasure5
        case strMeasure6, strMeasure7, strMeasure8, strMeasure9, strMeasure10
        case strMeasure11, strMeasure12, strMeasure13, strMeasure14, strMeasure15
        case strMeasure16, strMeasure17, strMeasure18, strMeasure19, strMeasure20
    }

    var ingredients: [(ingredient: String, measure: String)] {
        let raw: [(String?, String?)] = [
            (strIngredient1, strMeasure1), (strIngredient2, strMeasure2),
            (strIngredient3, strMeasure3), (strIngredient4, strMeasure4),
            (strIngredient5, strMeasure5), (strIngredient6, strMeasure6),
            (strIngredient7, strMeasure7), (strIngredient8, strMeasure8),
            (strIngredient9, strMeasure9), (strIngredient10, strMeasure10),
            (strIngredient11, strMeasure11), (strIngredient12, strMeasure12),
            (strIngredient13, strMeasure13), (strIngredient14, strMeasure14),
            (strIngredient15, strMeasure15), (strIngredient16, strMeasure16),
            (strIngredient17, strMeasure17), (strIngredient18, strMeasure18),
            (strIngredient19, strMeasure19), (strIngredient20, strMeasure20)
        ]
        return raw.compactMap { ingredient, measure in
            guard let ing = ingredient?.trimmingCharacters(in: .whitespacesAndNewlines), !ing.isEmpty else {
                return nil
            }
            let meas = measure?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (ingredient: ing, measure: meas)
        }
    }
}
