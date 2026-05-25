//
//  ApiRequestHelper.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

final class ApiRequestHelper {
    private let service: APIService

    init(_ service: APIService) {
        self.service = service
    }

    var requestHeaders: HTTPHeaders? {
        return service.headers
    }

    var fullURL: URL {
        return service.baseURL.appendingPathComponent(service.path)
    }
}
