//
//  MealCell.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit
import Kingfisher

final class MealCell: LayoutableCollectionViewCell {

    // MARK: - UI
    private lazy var thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .tertiarySystemBackground
        return iv
    }()

    private lazy var gradientOverlay: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.black.withAlphaComponent(0.0).cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        gradient.locations = [0.4, 1.0]
        return gradient
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layoutable
    func setupViews() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        contentView.addSubview(thumbnailImageView)
        thumbnailImageView.layer.addSublayer(gradientOverlay)
        contentView.addSubview(titleLabel)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        thumbnailImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(14)
            make.bottom.equalToSuperview().inset(14)
        }
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientOverlay.frame = thumbnailImageView.bounds
    }

    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.kf.cancelDownloadTask()
        thumbnailImageView.image = nil
        titleLabel.text = nil
    }

    // MARK: - Configure
    func configure(with item: MealListItem) {
        titleLabel.text = item.name
        thumbnailImageView.kf.setImage(with: item.thumbnailURL.flatMap(URL.init(string:)))
    }
}
