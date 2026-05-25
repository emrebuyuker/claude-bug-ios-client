//
//  CountryListViewModel.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

// MARK: - Delegate
protocol CountryListViewModelDelegate: AnyObject {
    func countryListViewModelDidUpdateItems()
    func countryListViewModelDidFailWith(error: Error)
    func countryListViewModelDidSelect(item: CountryListItem)
}

// MARK: - ViewModel
final class CountryListViewModel {

    // MARK: - Public
    weak var delegate: CountryListViewModelDelegate?
    private(set) var items: [CountryListItem] = []
    private(set) var isLoading: Bool = false

    // MARK: - Lifecycle
    func viewDidLoad() {
        fetchList()
    }

    // MARK: - Actions
    func didSelectItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        delegate?.countryListViewModelDidSelect(item: items[index])
    }

    // MARK: - Network
    private func fetchList() {
        guard !isLoading else { return }
        isLoading = true

        NetworkManager.shared.request(
            service: CountryService.list
        ) { [weak self] (result: Result<[CountryListItem], AFError>) in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .success(let response):
                self.items = response.sorted { $0.displayName < $1.displayName }
                self.delegate?.countryListViewModelDidUpdateItems()
            case .failure(let error):
                self.delegate?.countryListViewModelDidFailWith(error: error)
            }
        }
    }
}
