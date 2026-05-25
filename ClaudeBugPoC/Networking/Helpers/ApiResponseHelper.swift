//
//  ApiResponseHelper.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

final class ApiResponseHelper {
    static func mapStatusCodeToError(_ statusCode: Int?) -> ApiError? {
        guard let statusCode else { return nil }
        switch statusCode {
        case 200..<300:
            return nil
        case 401:
            return .unauthorized
        default:
            return .general
        }
    }

    static func prettyPrint(data: Data?) -> String {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let string = String(data: pretty, encoding: .utf8) else {
            return data.flatMap { String(data: $0, encoding: .utf8) } ?? "-"
        }
        return string
    }
}
