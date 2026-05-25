//
//  ApiError.swift
//  ClaudeBugPoC
//

import Foundation

enum ApiError: Error {
    case general
    case requestObjectCreate
    case jsonDecode
    case noSuchFile
    case timeOut
    case connection
    case unauthorized
}
