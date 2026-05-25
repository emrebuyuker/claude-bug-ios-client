//
//  LaunchListView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

protocol LaunchListViewDelegate: AnyObject {
    func launchListView(_ view: LaunchListView, didSelectItemAt index: Int)
}

final class LaunchListView: LayoutableView {

    // MARK: - Public
    weak var delegate: LaunchListViewDelegate?

    // MARK: - Private
    private var items: [Launch] = []

    // MARK: - UI
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.register(LaunchCell.self, forCellWithReuseIdentifier: LaunchCell.reuseIdentifier)
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
    func configure(with items: [Launch]) {
        self.items = items
        collectionView.reloadData()
    }

    func setLoading(_ loading: Bool) {
        loading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
    }
}

// MARK: - UICollectionViewDataSource
extension LaunchListView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: LaunchCell.reuseIdentifier,
            for: indexPath
        ) as? LaunchCell else { return UICollectionViewCell() }
        cell.configure(with: items[indexPath.item])
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension LaunchListView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        delegate?.launchListView(self, didSelectItemAt: indexPath.item)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension LaunchListView: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = collectionView.bounds.width - 32
        return CGSize(width: width, height: 88)
    }
}
