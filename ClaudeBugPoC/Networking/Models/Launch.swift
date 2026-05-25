//
//  Launch.swift
//  ClaudeBugPoC
//

import Foundation

struct Launch: Decodable {
    let id: String
    let name: String
    let dateUTC: String
    let success: Bool?
    let details: String?
    let flightNumber: Int?
    let links: LaunchLinks
    let rocket: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case dateUTC = "date_utc"
        case success
        case details
        case flightNumber = "flight_number"
        case links
        case rocket
    }

    var displayDate: String {
        let inFormatter = ISO8601DateFormatter()
        inFormatter.formatOptions = [.withInternetDateTime]
        guard let date = inFormatter.date(from: dateUTC) else { return dateUTC }
        let out = DateFormatter()
        out.locale = Locale(identifier: "tr_TR")
        out.dateFormat = "d MMM yyyy"
        return out.string(from: date)
    }

    var fullDisplayDate: String {
        let inFormatter = ISO8601DateFormatter()
        inFormatter.formatOptions = [.withInternetDateTime]
        guard let date = inFormatter.date(from: dateUTC) else { return dateUTC }
        let out = DateFormatter()
        out.locale = Locale(identifier: "tr_TR")
        out.dateStyle = .long
        out.timeStyle = .short
        return out.string(from: date)
    }

    var statusText: String {
        guard let success else { return "Bilinmiyor" }
        return success ? "Başarılı" : "Başarısız"
    }
}

struct LaunchLinks: Decodable {
    let patch: LaunchPatch?
    let webcast: String?
    let article: String?
    let wikipedia: String?
}

struct LaunchPatch: Decodable {
    let small: String?
    let large: String?
}
