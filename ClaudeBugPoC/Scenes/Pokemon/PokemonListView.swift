//
//  PokemonListView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

protocol PokemonListViewDelegate: AnyObject {
    func pokemonListView(_ view: PokemonListView, didSelectItemAt index: Int)
}

final class PokemonListView: LayoutableView {

    // MARK: - Public
    weak var delegate: PokemonListViewDelegate?

    // MARK: - Private
    private var items: [PokemonListItem] = []

    // MARK: - UI
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.register(PokemonCell.self, forCellWithReuseIdentifier: PokemonCell.reuseIdentifier)
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .systemBackground
        addSubview(collectionView)
        addSubview(loadingIndicator)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    // MARK: - Public
    func configure(with items: [PokemonListItem]) {
        self.items = items
        collectionView.reloadData()
    }

    func setLoading(_ loading: Bool) {
        loading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
    }
}

// MARK: - UICollectionViewDataSource
extension PokemonListView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PokemonCell.reuseIdentifier,
            for: indexPath
        ) as? PokemonCell else { return UICollectionViewCell() }
        cell.configure(with: items[indexPath.item])
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension PokemonListView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        delegate?.pokemonListView(self, didSelectItemAt: indexPath.item)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension PokemonListView: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = collectionView.bounds.width - 32
        return CGSize(width: width, height: 88)
    }
}
