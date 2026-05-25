//
//  PokemonListViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class PokemonListViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = PokemonListView
    private let viewModel: PokemonListViewModel

    // MARK: - Init
    init(viewModel: PokemonListViewModel = PokemonListViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "pokemonListViewController"
        layoutableView.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        layoutableView.setLoading(true)
        viewModel.viewDidLoad()
    }
}

// MARK: - PokemonListViewDelegate
extension PokemonListViewController: PokemonListViewDelegate {
    func pokemonListView(_ view: PokemonListView, didSelectItemAt index: Int) {
        viewModel.didSelectItem(at: index)
    }
}

// MARK: - PokemonListViewModelDelegate
extension PokemonListViewController: PokemonListViewModelDelegate {
    func pokemonListViewModelDidUpdateItems() {
        layoutableView.setLoading(false)
        layoutableView.configure(with: viewModel.items)
    }

    func pokemonListViewModelDidFailWith(error: Error) {
        layoutableView.setLoading(false)
        presentError(error)
    }

    func pokemonListViewModelDidSelect(item: PokemonListItem) {
        guard let id = item.id else { return }
        let detailVM = PokemonDetailViewModel(idOrName: String(id))
        let detailVC = PokemonDetailViewController(viewModel: detailVM)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(title: "Hata", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(alert, animated: true)
    }
}
