//
//  APIService.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

protocol APIService {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: HTTPHeaders? { get }
    var parameters: Parameters? { get }
    var encoding: ParameterEncoding { get }
}
