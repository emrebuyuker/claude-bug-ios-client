//
//  AIInspectorDetailCard.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

final class AIInspectorDetailCard: LayoutableView {

    // MARK: - UI
    private lazy var typeBadge: PaddedLabel = {
        let label = PaddedLabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = .systemIndigo
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        return label
    }()

    private lazy var sourceTagLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        return label
    }()

    private lazy var headerStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [typeBadge, sourceTagLabel, UIView()])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        return stack
    }()

    private lazy var primaryValueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private lazy var displayTextCaption: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = "TEXT"
        return label
    }()

    private lazy var displayTextLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var accessibilityCaption: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .tertiaryLabel
        label.text = "ACCESSIBILITY ID"
        return label
    }()

    private lazy var accessibilityIdValueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            headerStack,
            primaryValueLabel,
            displayTextCaption,
            displayTextLabel,
            accessibilityCaption,
            accessibilityIdValueLabel
        ])
        stack.axis = .vertical
        stack.spacing = 6
        stack.setCustomSpacing(10, after: headerStack)
        stack.setCustomSpacing(12, after: primaryValueLabel)
        stack.setCustomSpacing(12, after: displayTextLabel)
        return stack
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 14
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 14

        addSubview(contentStack)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(14)
        }
    }

    // MARK: - Configure
    func configure(payload: InspectionPayload) {
        typeBadge.text = payload.typeName

        if let key = payload.localizationKey {
            sourceTagLabel.text = LocalizationKey.View.AIInspector.localizationKeyLabel.localize
            sourceTagLabel.backgroundColor = .systemGreen
            primaryValueLabel.text = key
            primaryValueLabel.textColor = .systemGreen
        } else {
            sourceTagLabel.text = LocalizationKey.View.AIInspector.backendValueLabel.localize
            sourceTagLabel.backgroundColor = .systemOrange
            let value = payload.displayText?.isEmpty == false
                ? payload.displayText!
                : LocalizationKey.View.AIInspector.emptyText.localize
            primaryValueLabel.text = value
            primaryValueLabel.textColor = .systemOrange
        }

        if let text = payload.displayText, !text.isEmpty, payload.localizationKey != nil {
            displayTextCaption.isHidden = false
            displayTextLabel.isHidden = false
            displayTextLabel.text = text
        } else {
            displayTextCaption.isHidden = true
            displayTextLabel.isHidden = true
        }

        if let identifier = payload.accessibilityIdentifier, !identifier.isEmpty {
            accessibilityCaption.isHidden = false
            accessibilityIdValueLabel.isHidden = false
            accessibilityIdValueLabel.text = identifier
        } else {
            accessibilityCaption.isHidden = true
            accessibilityIdValueLabel.isHidden = true
        }
    }
}

// MARK: - PaddedLabel
final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
