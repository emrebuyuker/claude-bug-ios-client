//
//  PokemonDetail.swift
//  ClaudeBugPoC
//

import Foundation

struct PokemonDetail: Decodable {
    let id: Int
    let name: String
    let height: Int
    let weight: Int
    let sprites: PokemonSprites
    let types: [PokemonTypeSlot]
    let stats: [PokemonStat]
    let abilities: [PokemonAbilitySlot]

    var heightInMeters: Double { return Double(height) / 10.0 }
    var weightInKilograms: Double { return Double(weight) / 10.0 }
    var displayName: String { return name.prefix(1).uppercased() + name.dropFirst() }
    var formattedId: String { return String(format: "#%03d", id) }
}

struct PokemonSprites: Decodable {
    let frontDefault: String?
    let other: PokemonOtherSprites?

    enum CodingKeys: String, CodingKey {
        case frontDefault = "front_default"
        case other
    }

    var bestArtwork: String? {
        return other?.officialArtwork?.frontDefault ?? frontDefault
    }
}

struct PokemonOtherSprites: Decodable {
    let officialArtwork: PokemonArtwork?

    enum CodingKeys: String, CodingKey {
        case officialArtwork = "official-artwork"
    }
}

struct PokemonArtwork: Decodable {
    let frontDefault: String?

    enum CodingKeys: String, CodingKey {
        case frontDefault = "front_default"
    }
}

struct PokemonTypeSlot: Decodable {
    let slot: Int
    let type: PokemonNamedRef
}

struct PokemonNamedRef: Decodable {
    let name: String
    let url: String
}

struct PokemonStat: Decodable {
    let baseStat: Int
    let effort: Int
    let stat: PokemonNamedRef

    enum CodingKeys: String, CodingKey {
        case baseStat = "base_stat"
        case effort
        case stat
    }

    var displayName: String {
        switch stat.name {
        case "hp": return "HP"
        case "attack": return "Atak"
        case "defense": return "Savunma"
        case "special-attack": return "Sp. Atak"
        case "special-defense": return "Sp. Savunma"
        case "speed": return "Hız"
        default: return stat.name.capitalized
        }
    }
}

struct PokemonAbilitySlot: Decodable {
    let ability: PokemonNamedRef
    let isHidden: Bool
    let slot: Int

    enum CodingKeys: String, CodingKey {
        case ability
        case isHidden = "is_hidden"
        case slot
    }
}
