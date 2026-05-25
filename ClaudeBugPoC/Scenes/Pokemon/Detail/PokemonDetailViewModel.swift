//
//  PokemonDetailViewModel.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

// MARK: - Delegate
protocol PokemonDetailViewModelDelegate: AnyObject {
    func pokemonDetailViewModelDidLoad(detail: PokemonDetail)
    func pokemonDetailViewModelDidFailWith(error: Error)
}

// MARK: - ViewModel
final class PokemonDetailViewModel {

    // MARK: - Public
    weak var delegate: PokemonDetailViewModelDelegate?
    private(set) var detail: PokemonDetail?

    // MARK: - Private
    private let idOrName: String

    // MARK: - Init
    init(idOrName: String) {
        self.idOrName = idOrName
    }

    // MARK: - Lifecycle
    func viewDidLoad() {
        fetchDetail()
    }

    // MARK: - Network
    private func fetchDetail() {
        NetworkManager.shared.request(
            service: PokemonService.detail(idOrName: idOrName)
        ) { [weak self] (result: Result<PokemonDetail, AFError>) in
            guard let self else { return }
            switch result {
            case .success(let detail):
                self.detail = detail
                self.delegate?.pokemonDetailViewModelDidLoad(detail: detail)
            case .failure(let error):
                self.delegate?.pokemonDetailViewModelDidFailWith(error: error)
            }
        }
    }
}
