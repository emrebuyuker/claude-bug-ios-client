//
//  FigmaDifferenceCell.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

// MARK: - Delegate
protocol FigmaDifferenceCellDelegate: AnyObject {
    func figmaDifferenceCellDidTapEdit(_ cell: FigmaDifferenceCell, differenceId: UUID)
}

final class FigmaDifferenceCell: LayoutableCollectionViewCell {

    // MARK: - Public
    weak var delegate: FigmaDifferenceCellDelegate?

    // MARK: - Private
    private var differenceId: UUID?

    // MARK: - UI
    private lazy var categoryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var severityLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var codeHintLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        label.backgroundColor = .tertiarySystemBackground
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        return label
    }()

    private lazy var editButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = LocalizationKey.View.FigmaCompare.editButton.localize
        config.image = UIImage(systemName: "wand.and.stars")
        config.imagePadding = 6
        config.baseForegroundColor = .systemIndigo
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        var titleAttr = AttributeContainer()
        titleAttr.font = .systemFont(ofSize: 13, weight: .semibold)
        config.attributedTitle = AttributedString(
            LocalizationKey.View.FigmaCompare.editButton.localize,
            attributes: titleAttr
        )
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(handleEditTap), for: .touchUpInside)
        return button
    }()

    private lazy var container: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor.separator.cgColor
        view.addSubview(categoryLabel)
        view.addSubview(severityLabel)
        view.addSubview(titleLabel)
        view.addSubview(detailLabel)
        view.addSubview(codeHintLabel)
        view.addSubview(editButton)
        return view
    }()

    // MARK: - Constants
    static let editButtonAreaHeight: CGFloat = 44

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
        contentView.backgroundColor = .clear
        contentView.addSubview(container)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        container.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        categoryLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(14)
            make.trailing.lessThanOrEqualTo(severityLabel.snp.leading).offset(-8)
        }
        severityLabel.snp.makeConstraints { make in
            make.centerY.equalTo(categoryLabel)
            make.trailing.equalToSuperview().inset(14)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(categoryLabel.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(14)
        }
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(14)
        }
        codeHintLabel.snp.makeConstraints { make in
            make.top.equalTo(detailLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(14)
        }
        editButton.snp.makeConstraints { make in
            make.top.equalTo(codeHintLabel.snp.bottom).offset(10)
            make.trailing.equalToSuperview().inset(14)
            make.bottom.equalToSuperview().inset(10)
            make.height.equalTo(32)
        }
    }

    // MARK: - Configure
    func configure(with difference: FigmaDifference) {
        differenceId = difference.id
        categoryLabel.text = difference.category.localizationKey.localize
        severityLabel.text = difference.severity.localizationKey.localize
        titleLabel.text = difference.title
        detailLabel.text = difference.detail

        if let hint = difference.codeHint, !hint.isEmpty {
            codeHintLabel.text = "  " + hint + "  "
            codeHintLabel.isHidden = false
        } else {
            codeHintLabel.text = nil
            codeHintLabel.isHidden = true
        }
    }

    func setEditEnabled(_ enabled: Bool) {
        editButton.isEnabled = enabled
        editButton.alpha = enabled ? 1.0 : 0.5
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        differenceId = nil
        categoryLabel.text = nil
        severityLabel.text = nil
        titleLabel.text = nil
        detailLabel.text = nil
        codeHintLabel.text = nil
        codeHintLabel.isHidden = true
        editButton.isEnabled = true
        editButton.alpha = 1.0
    }

    // MARK: - Actions
    @objc private func handleEditTap() {
        guard let id = differenceId else { return }
        delegate?.figmaDifferenceCellDidTapEdit(self, differenceId: id)
    }
}
