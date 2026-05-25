//
//  PokemonListViewModel.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

// MARK: - Delegate
protocol PokemonListViewModelDelegate: AnyObject {
    func pokemonListViewModelDidUpdateItems()
    func pokemonListViewModelDidFailWith(error: Error)
    func pokemonListViewModelDidSelect(item: PokemonListItem)
}

// MARK: - ViewModel
final class PokemonListViewModel {

    // MARK: - Public
    weak var delegate: PokemonListViewModelDelegate?
    private(set) var items: [PokemonListItem] = []
    private(set) var isLoading: Bool = false

    // MARK: - Private
    private let pageSize: Int = 50

    // MARK: - Lifecycle
    func viewDidLoad() {
        fetchList()
    }

    // MARK: - Actions
    func didSelectItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        delegate?.pokemonListViewModelDidSelect(item: items[index])
    }

    // MARK: - Network
    private func fetchList() {
        guard !isLoading else { return }
        isLoading = true

        NetworkManager.shared.request(
            service: PokemonService.list(limit: pageSize, offset: 0)
        ) { [weak self] (result: Result<PokemonListResponse, AFError>) in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .success(let response):
                self.items = response.results
                self.delegate?.pokemonListViewModelDidUpdateItems()
            case .failure(let error):
                self.delegate?.pokemonListViewModelDidFailWith(error: error)
            }
        }
    }
}
