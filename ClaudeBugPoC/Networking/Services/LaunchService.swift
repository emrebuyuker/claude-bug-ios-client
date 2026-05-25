//
//  LaunchService.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

enum LaunchService: APIService {
    case past
    case detail(id: String)
}

extension LaunchService {
    var baseURL: URL {
        return URL(string: "https://api.spacexdata.com/v5/")!
    }

    var path: String {
        switch self {
        case .past: return "launches/past"
        case .detail(let id): return "launches/\(id)"
        }
    }

    var method: HTTPMethod {
        return .get
    }

    var headers: HTTPHeaders? {
        return ["Accept": "application/json"]
    }

    var parameters: Parameters? {
        return nil
    }

    var encoding: ParameterEncoding {
        return URLEncoding.default
    }
}
