//
//  MovieDetail.swift
//  ClaudeBugPoC
//

import Foundation

struct MovieDetail: Decodable, Identifiable {
    let id: Int
    let title: String
    let tagline: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let runtime: Int?
    let voteAverage: Double?
    let voteCount: Int?
    let genres: [Genre]
    let homepage: String?
    let status: String?
    let credits: Credits?
    let videos: VideoList?
    let similar: PagedResponse<Movie>?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case tagline
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case runtime
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genres
        case homepage
        case status
        case credits
        case videos
        case similar
    }
}

struct Genre: Decodable, Identifiable {
    let id: Int
    let name: String
}

struct Credits: Decodable {
    let cast: [CastMember]
    let crew: [CrewMember]
}

struct CastMember: Decodable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case character
        case profilePath = "profile_path"
        case order
    }
}

struct CrewMember: Decodable, Identifiable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case job
        case department
        case profilePath = "profile_path"
    }
}

struct VideoList: Decodable {
    let results: [Video]
}

struct Video: Decodable, Identifiable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
}
