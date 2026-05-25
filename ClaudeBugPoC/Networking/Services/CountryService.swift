//
//  CountryService.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

enum CountryService: APIService {
    case list
    case detail(code: String)
}

extension CountryService {
    var baseURL: URL {
        return URL(string: "https://restcountries.com/v3.1/")!
    }

    var path: String {
        switch self {
        case .list:
            return "all"
        case .detail(let code):
            return "alpha/\(code)"
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
        case .list:
            return ["fields": "name,flags,capital,region,population,cca2"]
        case .detail:
            return nil
        }
    }

    var encoding: ParameterEncoding {
        return URLEncoding.default
    }
}
