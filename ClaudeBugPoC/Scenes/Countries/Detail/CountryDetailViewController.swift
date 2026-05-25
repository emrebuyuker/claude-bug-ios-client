//
//  CountryDetailViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class CountryDetailViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = CountryDetailView
    private let viewModel: CountryDetailViewModel

    // MARK: - Init
    init(viewModel: CountryDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "countryDetailViewController"
        layoutableView.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        viewModel.delegate = self
        layoutableView.setLoading(true)
        viewModel.viewDidLoad()
    }
}

// MARK: - CountryDetailViewDelegate
extension CountryDetailViewController: CountryDetailViewDelegate {
    func countryDetailViewDidTapMap(_ view: CountryDetailView) {
        guard let urlString = viewModel.detail?.maps?.googleMaps, let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - CountryDetailViewModelDelegate
extension CountryDetailViewController: CountryDetailViewModelDelegate {
    func countryDetailViewModelDidLoad(detail: CountryDetail) {
        title = detail.name.common
        layoutableView.setLoading(false)
        layoutableView.configure(with: detail)
    }

    func countryDetailViewModelDidFailWith(error: Error) {
        layoutableView.setLoading(false)
        let alert = UIAlertController(title: "Hata", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(alert, animated: true)
    }
}
