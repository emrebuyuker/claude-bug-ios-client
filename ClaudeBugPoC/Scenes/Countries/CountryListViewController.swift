//
//  CountryListViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class CountryListViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = CountryListView
    private let viewModel: CountryListViewModel

    // MARK: - Init
    init(viewModel: CountryListViewModel = CountryListViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "countryListViewController"
        layoutableView.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        layoutableView.setLoading(true)
        viewModel.viewDidLoad()
    }
}

// MARK: - CountryListViewDelegate
extension CountryListViewController: CountryListViewDelegate {
    func countryListView(_ view: CountryListView, didSelectItemAt index: Int) {
        viewModel.didSelectItem(at: index)
    }
}

// MARK: - CountryListViewModelDelegate
extension CountryListViewController: CountryListViewModelDelegate {
    func countryListViewModelDidUpdateItems() {
        layoutableView.setLoading(false)
        layoutableView.configure(with: viewModel.items)
    }

    func countryListViewModelDidFailWith(error: Error) {
        layoutableView.setLoading(false)
        let alert = UIAlertController(
            title: LocalizationKey.View.Common.errorAlertTitle.localize,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizationKey.View.Common.okButton.localize, style: .default))
        present(alert, animated: true)
    }

    func countryListViewModelDidSelect(item: CountryListItem) {
        let detailVM = CountryDetailViewModel(code: item.cca2)
        let detailVC = CountryDetailViewController(viewModel: detailVM)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
