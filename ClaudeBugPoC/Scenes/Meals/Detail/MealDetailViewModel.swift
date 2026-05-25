//
//  MealDetailViewModel.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

// MARK: - Delegate
protocol MealDetailViewModelDelegate: AnyObject {
    func mealDetailViewModelDidLoad(detail: MealDetail)
    func mealDetailViewModelDidFailWith(error: Error)
}

// MARK: - ViewModel
final class MealDetailViewModel {

    // MARK: - Public
    weak var delegate: MealDetailViewModelDelegate?
    private(set) var detail: MealDetail?

    // MARK: - Private
    private let id: String

    // MARK: - Init
    init(id: String) {
        self.id = id
    }

    // MARK: - Lifecycle
    func viewDidLoad() {
        fetchDetail()
    }

    // MARK: - Network
    private func fetchDetail() {
        NetworkManager.shared.request(
            service: MealService.detail(id: id)
        ) { [weak self] (result: Result<MealDetailResponse, AFError>) in
            guard let self else { return }
            switch result {
            case .success(let response):
                guard let meal = response.meals?.first else {
                    self.delegate?.mealDetailViewModelDidFailWith(error: MealDetailError.notFound)
                    return
                }
                self.detail = meal
                self.delegate?.mealDetailViewModelDidLoad(detail: meal)
            case .failure(let error):
                self.delegate?.mealDetailViewModelDidFailWith(error: error)
            }
        }
    }
}

enum MealDetailError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Tarif bulunamadı."
        }
    }
}
