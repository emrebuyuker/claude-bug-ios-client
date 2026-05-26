//
//  MealListViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class MealListViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = MealListView
    private let viewModel: MealListViewModel

    // MARK: - Init
    init(viewModel: MealListViewModel = MealListViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "mealListViewController"
        layoutableView.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        layoutableView.setLoading(true)
        viewModel.viewDidLoad()
    }
}

// MARK: - MealListViewDelegate
extension MealListViewController: MealListViewDelegate {
    func mealListView(_ view: MealListView, didSelectItemAt index: Int) {
        viewModel.didSelectItem(at: index)
    }
}

// MARK: - MealListViewModelDelegate
extension MealListViewController: MealListViewModelDelegate {
    func mealListViewModelDidUpdateItems() {
        layoutableView.setLoading(false)
        layoutableView.configure(with: viewModel.items)
    }

    func mealListViewModelDidFailWith(error: Error) {
        layoutableView.setLoading(false)
        let alert = UIAlertController(
            title: LocalizationKey.View.Common.errorAlertTitle.localize,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizationKey.View.Common.okButton.localize, style: .default))
        present(alert, animated: true)
    }

    func mealListViewModelDidSelect(item: MealListItem) {
        let detailVM = MealDetailViewModel(id: item.id)
        let detailVC = MealDetailViewController(viewModel: detailVM)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
