//
//  AIFloatingMenuView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

// MARK: - Delegate
protocol AIFloatingMenuViewDelegate: AnyObject {
    func aiFloatingMenuViewDidSelectContact(_ view: AIFloatingMenuView)
    func aiFloatingMenuViewDidSelectInspect(_ view: AIFloatingMenuView)
    func aiFloatingMenuViewDidSelectFigmaCompare(_ view: AIFloatingMenuView)
    func aiFloatingMenuViewDidSelectFigmaCompareGemini(_ view: AIFloatingMenuView)
}

// MARK: - Menu
final class AIFloatingMenuView: LayoutableView {

    // MARK: - Public
    weak var delegate: AIFloatingMenuViewDelegate?

    // 280: so the longest title ("🎨  Figma ile Karşılaştır (Claude)" ≈ 230pt) fits on
    // a single line with the content insets (16+16) — at 240 it wraps to two lines.
    static let preferredWidth: CGFloat = 280
    static let spacingFromButton: CGFloat = 8

    // MARK: - UI
    private lazy var contactButton: UIButton = {
        let button = makeMenuButton(
            titleKey: LocalizationKey.View.AIAssistant.menuContact,
            action: #selector(handleContactTap)
        )
        return button
    }()

    private lazy var separator: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    private lazy var inspectButton: UIButton = {
        let button = makeMenuButton(
            titleKey: LocalizationKey.View.AIAssistant.menuInspect,
            action: #selector(handleInspectTap)
        )
        return button
    }()

    private lazy var secondSeparator: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    private lazy var figmaCompareButton: UIButton = {
        let button = makeMenuButton(
            titleKey: LocalizationKey.View.AIAssistant.menuFigmaCompare,
            action: #selector(handleFigmaCompareTap)
        )
        return button
    }()

    private lazy var thirdSeparator: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    private lazy var figmaCompareGeminiButton: UIButton = {
        let button = makeMenuButton(
            titleKey: LocalizationKey.View.AIAssistant.menuFigmaCompareGemini,
            action: #selector(handleFigmaCompareGeminiTap)
        )
        return button
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            contactButton,
            separator,
            inspectButton,
            secondSeparator,
            figmaCompareButton,
            thirdSeparator,
            figmaCompareGeminiButton
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 0
        return stack
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 14
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        isUserInteractionEnabled = true
        clipsToBounds = false

        addSubview(stackView)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        separator.snp.makeConstraints { make in
            make.height.equalTo(0.5)
        }
        secondSeparator.snp.makeConstraints { make in
            make.height.equalTo(0.5)
        }
        thirdSeparator.snp.makeConstraints { make in
            make.height.equalTo(0.5)
        }
    }

    // MARK: - Public
    func presentWithAnimation() {
        transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        alpha = 0
        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.6,
            options: [.allowUserInteraction]
        ) {
            self.transform = .identity
            self.alpha = 1
        }
    }

    func dismissWithAnimation(completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.15,
            animations: {
                self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                self.alpha = 0
            },
            completion: { _ in completion?() }
        )
    }

    // MARK: - Actions
    @objc private func handleContactTap() {
        delegate?.aiFloatingMenuViewDidSelectContact(self)
    }

    @objc private func handleInspectTap() {
        delegate?.aiFloatingMenuViewDidSelectInspect(self)
    }

    @objc private func handleFigmaCompareTap() {
        delegate?.aiFloatingMenuViewDidSelectFigmaCompare(self)
    }

    @objc private func handleFigmaCompareGeminiTap() {
        delegate?.aiFloatingMenuViewDidSelectFigmaCompareGemini(self)
    }

    // MARK: - Helpers
    private func makeMenuButton(titleKey: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = titleKey.localize
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.titleAlignment = .leading
        var titleAttributes = AttributeContainer()
        titleAttributes.font = .systemFont(ofSize: 15, weight: .medium)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = .systemFont(ofSize: 15, weight: .medium)
            return attrs
        }
        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}
