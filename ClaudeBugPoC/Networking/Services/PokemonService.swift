//
//  PokemonService.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

enum PokemonService: APIService {
    case list(limit: Int, offset: Int)
    case detail(idOrName: String)
}

extension PokemonService {
    var baseURL: URL {
        return URL(string: "https://pokeapi.co/api/v2/")!
    }

    var path: String {
        switch self {
        case .list:
            return "pokemon"
        case .detail(let idOrName):
            return "pokemon/\(idOrName)"
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
        case .list(let limit, let offset):
            return ["limit": limit, "offset": offset]
        case .detail:
            return nil
        }
    }

    var encoding: ParameterEncoding {
        return URLEncoding.default
    }
}
