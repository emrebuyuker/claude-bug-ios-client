//
//  ApiConstant.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

enum ApiConstant: String {
    static let baseURL: URL = URL(string: "https://api.themoviedb.org/3/")!
    static let imageBaseURL: URL = URL(string: "https://image.tmdb.org/t/p/")!

    // TMDB v4 read access token. Replace with your own from
    // https://www.themoviedb.org/settings/api (Read Access Token).
    static let bearerToken: String = "YOUR_TMDB_V4_TOKEN_HERE"

    static func getHeaders() -> HTTPHeaders {
        return [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer \(bearerToken)"
        ]
    }

    // MARK: - Paths
    case popularMovies = "movie/popular"
    case movieDetail = "movie/{id}"
}
