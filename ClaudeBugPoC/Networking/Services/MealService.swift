//
//  MealService.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

enum MealService: APIService {
    case listByCategory(String)
    case detail(id: String)
}

extension MealService {
    var baseURL: URL {
        return URL(string: "https://www.themealdb.com/api/json/v1/1/")!
    }

    var path: String {
        switch self {
        case .listByCategory: return "filter.php"
        case .detail: return "lookup.php"
        }
    }

    var method: HTTPMethod {
        return .get
    }

    var headers: HTTPHeaders? {
        return ["Accept": "application/json"]
    }

    var parameters: Parameters? {
        switch self {
        case .listByCategory(let category):
            return ["c": category]
        case .detail(let id):
            return ["i": id]
        }
    }

    var encoding: ParameterEncoding {
        return URLEncoding.default
    }
}
