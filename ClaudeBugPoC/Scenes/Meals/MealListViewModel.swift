//
//  MealListViewModel.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

// MARK: - Delegate
protocol MealListViewModelDelegate: AnyObject {
    func mealListViewModelDidUpdateItems()
    func mealListViewModelDidFailWith(error: Error)
    func mealListViewModelDidSelect(item: MealListItem)
}

// MARK: - ViewModel
final class MealListViewModel {

    // MARK: - Public
    weak var delegate: MealListViewModelDelegate?
    private(set) var items: [MealListItem] = []
    private(set) var isLoading: Bool = false
    let category: String

    // MARK: - Init
    init(category: String = "Seafood") {
        self.category = category
    }

    // MARK: - Lifecycle
    func viewDidLoad() {
        fetchList()
    }

    // MARK: - Actions
    func didSelectItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        delegate?.mealListViewModelDidSelect(item: items[index])
    }

    // MARK: - Network
    private func fetchList() {
        guard !isLoading else { return }
        isLoading = true

        NetworkManager.shared.request(
            service: MealService.listByCategory(category)
        ) { [weak self] (result: Result<MealListResponse, AFError>) in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .success(let response):
                self.items = response.meals ?? []
                self.delegate?.mealListViewModelDidUpdateItems()
            case .failure(let error):
                self.delegate?.mealListViewModelDidFailWith(error: error)
            }
        }
    }
}
