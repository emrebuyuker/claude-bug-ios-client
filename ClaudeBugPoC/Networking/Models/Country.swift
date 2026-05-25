//
//  Country.swift
//  ClaudeBugPoC
//

import Foundation

struct CountryListItem: Decodable {
    let name: CountryName
    let flags: CountryFlags
    let capital: [String]?
    let region: String?
    let population: Int?
    let cca2: String

    var displayName: String { return name.common }
    var displayCapital: String { return capital?.first ?? "—" }
}

struct CountryName: Decodable {
    let common: String
    let official: String
}

struct CountryFlags: Decodable {
    let png: String?
    let svg: String?
    let alt: String?
}

struct CountryDetail: Decodable {
    let name: CountryName
    let flags: CountryFlags
    let capital: [String]?
    let region: String?
    let subregion: String?
    let population: Int?
    let area: Double?
    let languages: [String: String]?
    let currencies: [String: CountryCurrency]?
    let timezones: [String]?
    let borders: [String]?
    let continents: [String]?
    let cca2: String
    let maps: CountryMaps?

    var formattedPopulation: String {
        guard let population else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: population)) ?? "\(population)"
    }

    var formattedArea: String {
        guard let area else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: area)) ?? "\(Int(area))"
        return "\(formatted) km²"
    }

    var languagesText: String {
        return languages?.values.sorted().joined(separator: ", ") ?? "—"
    }

    var currenciesText: String {
        guard let currencies, !currencies.isEmpty else { return "—" }
        return currencies.values
            .map { "\($0.name) (\($0.symbol ?? ""))" }
            .sorted()
            .joined(separator: ", ")
    }
}

struct CountryCurrency: Decodable {
    let name: String
    let symbol: String?
}

struct CountryMaps: Decodable {
    let googleMaps: String?
    let openStreetMaps: String?
}
