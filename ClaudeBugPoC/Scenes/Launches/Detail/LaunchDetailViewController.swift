//
//  LaunchDetailViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class LaunchDetailViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = LaunchDetailView
    private let viewModel: LaunchDetailViewModel

    // MARK: - Init
    init(viewModel: LaunchDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "launchDetailViewController"
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

// MARK: - LaunchDetailViewDelegate
extension LaunchDetailViewController: LaunchDetailViewDelegate {
    func launchDetailView(_ view: LaunchDetailView, didTapLink kind: LaunchDetailView.LinkKind) {
        let urlString: String? = {
            switch kind {
            case .webcast: return viewModel.detail?.links.webcast
            case .article: return viewModel.detail?.links.article
            case .wikipedia: return viewModel.detail?.links.wikipedia
            }
        }()
        guard let urlString, let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - LaunchDetailViewModelDelegate
extension LaunchDetailViewController: LaunchDetailViewModelDelegate {
    func launchDetailViewModelDidLoad(detail: Launch) {
        title = detail.name
        layoutableView.setLoading(false)
        layoutableView.configure(with: detail)
    }

    func launchDetailViewModelDidFailWith(error: Error) {
        layoutableView.setLoading(false)
        let alert = UIAlertController(title: "Hata", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(alert, animated: true)
    }
}
