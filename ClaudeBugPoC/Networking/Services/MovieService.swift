//
//  MovieService.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

enum MovieService: APIService {
    case popular(page: Int)
    case detail(id: Int)
}

extension MovieService {
    var baseURL: URL {
        return ApiConstant.baseURL
    }

    var path: String {
        switch self {
        case .popular:
            return ApiConstant.popularMovies.rawValue
        case .detail(let id):
            return "movie/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .popular, .detail:
            return .get
        }
    }

    var headers: HTTPHeaders? {
        return ApiConstant.getHeaders()
    }

    var parameters: Parameters? {
        switch self {
        case .popular(let page):
            return ["page": page, "language": "en-US"]
        case .detail:
            return ["language": "en-US", "append_to_response": "credits,videos,images,similar"]
        }
    }

    var encoding: ParameterEncoding {
        return URLEncoding.default
    }
}
