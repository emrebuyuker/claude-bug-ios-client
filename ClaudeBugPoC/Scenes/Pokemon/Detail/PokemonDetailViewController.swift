//
//  PokemonDetailViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class PokemonDetailViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = PokemonDetailView
    private let viewModel: PokemonDetailViewModel

    // MARK: - Init
    init(viewModel: PokemonDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "pokemonDetailViewController"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        viewModel.delegate = self
        layoutableView.setLoading(true)
        viewModel.viewDidLoad()
    }
}

// MARK: - PokemonDetailViewModelDelegate
extension PokemonDetailViewController: PokemonDetailViewModelDelegate {
    func pokemonDetailViewModelDidLoad(detail: PokemonDetail) {
        title = detail.displayName
        layoutableView.setLoading(false)
        layoutableView.configure(with: detail)
    }

    func pokemonDetailViewModelDidFailWith(error: Error) {
        layoutableView.setLoading(false)
        let alert = UIAlertController(
            title: LocalizationKey.View.Common.errorAlertTitle.localize,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizationKey.View.Common.okButton.localize, style: .default))
        present(alert, animated: true)
    }
}
