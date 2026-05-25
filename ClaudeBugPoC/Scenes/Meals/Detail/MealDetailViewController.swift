//
//  MealDetailViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class MealDetailViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = MealDetailView
    private let viewModel: MealDetailViewModel

    // MARK: - Init
    init(viewModel: MealDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "mealDetailViewController"
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

// MARK: - MealDetailViewDelegate
extension MealDetailViewController: MealDetailViewDelegate {
    func mealDetailViewDidTapYoutube(_ view: MealDetailView) {
        guard let urlString = viewModel.detail?.youtubeURL, let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - MealDetailViewModelDelegate
extension MealDetailViewController: MealDetailViewModelDelegate {
    func mealDetailViewModelDidLoad(detail: MealDetail) {
        title = detail.name
        layoutableView.setLoading(false)
        layoutableView.configure(with: detail)
    }

    func mealDetailViewModelDidFailWith(error: Error) {
        layoutableView.setLoading(false)
        let alert = UIAlertController(title: "Hata", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(alert, animated: true)
    }
}
