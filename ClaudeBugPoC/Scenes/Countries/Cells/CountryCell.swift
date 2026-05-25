//
//  CountryCell.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit
import Kingfisher

final class CountryCell: LayoutableCollectionViewCell {

    // MARK: - UI
    private lazy var flagImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.layer.borderColor = UIColor.separator.cgColor
        iv.layer.borderWidth = 0.5
        iv.backgroundColor = .tertiarySystemBackground
        return iv
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var chevron: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.right"))
        iv.tintColor = .tertiaryLabel
        return iv
    }()

    private lazy var textStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
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
        contentView.addSubview(flagImageView)
        contentView.addSubview(textStack)
        contentView.addSubview(chevron)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        flagImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.width.equalTo(56)
            make.height.equalTo(36)
        }
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(flagImageView.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(chevron.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(14)
        }
    }

    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        flagImageView.kf.cancelDownloadTask()
        flagImageView.image = nil
        nameLabel.text = nil
        subtitleLabel.text = nil
    }

    // MARK: - Configure
    func configure(with item: CountryListItem) {
        nameLabel.text = item.displayName
        let parts = [item.region, item.displayCapital].compactMap { $0 }.filter { !$0.isEmpty }
        subtitleLabel.text = parts.joined(separator: " • ")
        flagImageView.kf.setImage(with: (item.flags.png ?? item.flags.svg).flatMap(URL.init(string:)))
    }
}
