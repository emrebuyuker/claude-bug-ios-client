//
//  LaunchListViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class LaunchListViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = LaunchListView
    private let viewModel: LaunchListViewModel

    // MARK: - Init
    init(viewModel: LaunchListViewModel = LaunchListViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "launchListViewController"
        layoutableView.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        layoutableView.setLoading(true)
        viewModel.viewDidLoad()
    }
}

// MARK: - LaunchListViewDelegate
extension LaunchListViewController: LaunchListViewDelegate {
    func launchListView(_ view: LaunchListView, didSelectItemAt index: Int) {
        viewModel.didSelectItem(at: index)
    }
}

// MARK: - LaunchListViewModelDelegate
extension LaunchListViewController: LaunchListViewModelDelegate {
    func launchListViewModelDidUpdateItems() {
        layoutableView.setLoading(false)
        layoutableView.configure(with: viewModel.items)
    }

    func launchListViewModelDidFailWith(error: Error) {
        layoutableView.setLoading(false)
        let alert = UIAlertController(
            title: LocalizationKey.View.Common.errorAlertTitle.localize,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizationKey.View.Common.okButton.localize, style: .default))
        present(alert, animated: true)
    }

    func launchListViewModelDidSelect(item: Launch) {
        let detailVM = LaunchDetailViewModel(id: item.id)
        let detailVC = LaunchDetailViewController(viewModel: detailVM)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
