//
//  PokemonCell.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit
import Kingfisher

final class PokemonCell: LayoutableCollectionViewCell {

    // MARK: - UI
    private lazy var iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.backgroundColor = .tertiarySystemBackground
        iv.layer.cornerRadius = 8
        return iv
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private lazy var idLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var textStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [nameLabel, idLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        return stack
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
        contentView.layer.cornerRadius = 12
        contentView.addSubview(iconImageView)
        contentView.addSubview(textStack)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(64)
        }
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.kf.cancelDownloadTask()
        iconImageView.image = nil
        nameLabel.text = nil
        idLabel.text = nil
    }

    // MARK: - Configure
    func configure(with item: PokemonListItem) {
        nameLabel.text = item.displayName
        if let id = item.id {
            idLabel.text = String(format: "#%03d", id)
        }
        iconImageView.kf.setImage(with: item.spriteURL.flatMap(URL.init(string:)))
    }
}
