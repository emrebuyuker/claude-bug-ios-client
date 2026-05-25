//
//  CountryDetailViewModel.swift
//  ClaudeBugPoC
//

import Foundation
import Alamofire

// MARK: - Delegate
protocol CountryDetailViewModelDelegate: AnyObject {
    func countryDetailViewModelDidLoad(detail: CountryDetail)
    func countryDetailViewModelDidFailWith(error: Error)
}

// MARK: - ViewModel
final class CountryDetailViewModel {

    // MARK: - Public
    weak var delegate: CountryDetailViewModelDelegate?
    private(set) var detail: CountryDetail?

    // MARK: - Private
    private let code: String

    // MARK: - Init
    init(code: String) {
        self.code = code
    }

    // MARK: - Lifecycle
    func viewDidLoad() {
        fetchDetail()
    }

    // MARK: - Network
    private func fetchDetail() {
        NetworkManager.shared.request(
            service: CountryService.detail(code: code)
        ) { [weak self] (result: Result<[CountryDetail], AFError>) in
            guard let self else { return }
            switch result {
            case .success(let response):
                guard let country = response.first else {
                    self.delegate?.countryDetailViewModelDidFailWith(error: CountryDetailError.notFound)
                    return
                }
                self.detail = country
                self.delegate?.countryDetailViewModelDidLoad(detail: country)
            case .failure(let error):
                self.delegate?.countryDetailViewModelDidFailWith(error: error)
            }
        }
    }
}

enum CountryDetailError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Ülke bulunamadı."
        }
    }
}
