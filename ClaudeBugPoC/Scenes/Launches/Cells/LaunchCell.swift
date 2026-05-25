//
//  LaunchCell.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit
import Kingfisher

final class LaunchCell: LayoutableCollectionViewCell {

    // MARK: - UI
    private lazy var patchImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .tertiarySystemBackground
        iv.layer.cornerRadius = 8
        iv.clipsToBounds = true
        return iv
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()

    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var statusBadge: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        return label
    }()

    private lazy var textStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [nameLabel, dateLabel])
        stack.axis = .vertical
        stack.spacing = 4
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
        contentView.addSubview(patchImageView)
        contentView.addSubview(textStack)
        contentView.addSubview(statusBadge)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        patchImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(64)
        }
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(patchImageView.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(statusBadge.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        statusBadge.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.height.equalTo(22)
            make.width.greaterThanOrEqualTo(68)
        }
    }

    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        patchImageView.kf.cancelDownloadTask()
        patchImageView.image = nil
        nameLabel.text = nil
        dateLabel.text = nil
    }

    // MARK: - Configure
    func configure(with launch: Launch) {
        nameLabel.text = launch.name
        dateLabel.text = launch.displayDate
        statusBadge.text = " \(launch.statusText) "

        switch launch.success {
        case true: statusBadge.backgroundColor = .systemGreen
        case false: statusBadge.backgroundColor = .systemRed
        default: statusBadge.backgroundColor = .systemGray
        }

        let patch = launch.links.patch?.small ?? launch.links.patch?.large
        patchImageView.kf.setImage(
            with: patch.flatMap(URL.init(string:)),
            placeholder: UIImage(systemName: "airplane.circle")
        )
    }
}
