//
//  Pokemon.swift
//  ClaudeBugPoC
//

import Foundation

struct PokemonListResponse: Decodable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [PokemonListItem]
}

struct PokemonListItem: Decodable {
    let name: String
    let url: String

    var id: Int? {
        let trimmed = url.hasSuffix("/") ? String(url.dropLast()) : url
        guard let last = trimmed.split(separator: "/").last else { return nil }
        return Int(last)
    }

    var spriteURL: String? {
        guard let id else { return nil }
        return "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(id).png"
    }

    var displayName: String {
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}
