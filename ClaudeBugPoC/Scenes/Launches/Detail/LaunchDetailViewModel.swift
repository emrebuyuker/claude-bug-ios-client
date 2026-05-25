//
//  LaunchDetailViewModel.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

// MARK: - Delegate
protocol LaunchDetailViewModelDelegate: AnyObject {
    func launchDetailViewModelDidLoad(detail: Launch)
    func launchDetailViewModelDidFailWith(error: Error)
}

// MARK: - ViewModel
final class LaunchDetailViewModel {

    // MARK: - Public
    weak var delegate: LaunchDetailViewModelDelegate?
    private(set) var detail: Launch?

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
            service: LaunchService.detail(id: id)
        ) { [weak self] (result: Result<Launch, AFError>) in
            guard let self else { return }
            switch result {
            case .success(let detail):
                self.detail = detail
                self.delegate?.launchDetailViewModelDidLoad(detail: detail)
            case .failure(let error):
                self.delegate?.launchDetailViewModelDidFailWith(error: error)
            }
        }
    }
}
