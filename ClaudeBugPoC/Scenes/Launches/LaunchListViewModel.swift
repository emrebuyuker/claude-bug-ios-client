//
//  LaunchListViewModel.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

// MARK: - Delegate
protocol LaunchListViewModelDelegate: AnyObject {
    func launchListViewModelDidUpdateItems()
    func launchListViewModelDidFailWith(error: Error)
    func launchListViewModelDidSelect(item: Launch)
}

// MARK: - ViewModel
final class LaunchListViewModel {

    // MARK: - Public
    weak var delegate: LaunchListViewModelDelegate?
    private(set) var items: [Launch] = []
    private(set) var isLoading: Bool = false

    // MARK: - Lifecycle
    func viewDidLoad() {
        fetchList()
    }

    // MARK: - Actions
    func didSelectItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        delegate?.launchListViewModelDidSelect(item: items[index])
    }

    // MARK: - Network
    private func fetchList() {
        guard !isLoading else { return }
        isLoading = true

        NetworkManager.shared.request(
            service: LaunchService.past
        ) { [weak self] (result: Result<[Launch], AFError>) in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .success(let response):
                self.items = response.sorted { $0.dateUTC > $1.dateUTC }
                self.delegate?.launchListViewModelDidUpdateItems()
            case .failure(let error):
                self.delegate?.launchListViewModelDidFailWith(error: error)
            }
        }
    }
}
