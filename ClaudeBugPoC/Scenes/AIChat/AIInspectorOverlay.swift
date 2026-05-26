//
//  AIInspectorOverlay.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

// MARK: - Delegate
protocol AIInspectorOverlayDelegate: AnyObject {
    func aiInspectorOverlayDidRequestDismiss(_ overlay: AIInspectorOverlay)
}

// MARK: - Overlay
final class AIInspectorOverlay: LayoutableView {

    // MARK: - Public
    weak var delegate: AIInspectorOverlayDelegate?

    // MARK: - UI
    private lazy var banner: UIView = {
        let view = UIView()
        view.backgroundColor = .systemIndigo
        view.layer.cornerRadius = 14
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.22
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 10

        view.addSubview(bannerTitleLabel)
        view.addSubview(bannerHintLabel)
        view.addSubview(closeButton)
        return view
    }()

    private lazy var bannerTitleLabel: UILabel = {
        let label = UILabel()
        label.text = LocalizationKey.View.AIInspector.title.localize
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        return label
    }()

    private lazy var bannerHintLabel: UILabel = {
        let label = UILabel()
        label.text = LocalizationKey.View.AIInspector.hint.localize
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.numberOfLines = 2
        return label
    }()

    private lazy var closeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(
            systemName: "xmark.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
        )
        config.baseForegroundColor = .white
        config.contentInsets = .zero
        let button = UIButton(configuration: config)
        button.accessibilityLabel = LocalizationKey.View.AIInspector.close.localize
        button.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        return button
    }()

    private lazy var highlightView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.18)
        view.layer.borderColor = UIColor.systemIndigo.cgColor
        view.layer.borderWidth = 2
        view.layer.cornerRadius = 6
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var detailCard: AIInspectorDetailCard = {
        let card = AIInspectorDetailCard.create()
        card.isHidden = true
        return card
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.05)

        addSubview(highlightView)
        addSubview(banner)
        addSubview(detailCard)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = true
        addGestureRecognizer(tap)

        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        banner.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        bannerTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(14)
            make.trailing.lessThanOrEqualTo(closeButton.snp.leading).offset(-8)
        }
        bannerHintLabel.snp.makeConstraints { make in
            make.top.equalTo(bannerTitleLabel.snp.bottom).offset(2)
            make.leading.equalToSuperview().offset(14)
            make.trailing.lessThanOrEqualTo(closeButton.snp.leading).offset(-8)
            make.bottom.equalToSuperview().inset(10)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
        detailCard.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(24)
        }
    }

    // MARK: - Public
    func presentWithAnimation() {
        alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: -20)
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.allowUserInteraction]
        ) {
            self.alpha = 1
            self.banner.transform = .identity
        }
    }

    func dismissWithAnimation(completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.18,
            animations: { self.alpha = 0 },
            completion: { _ in completion?() }
        )
    }

    // MARK: - Actions
    @objc private func handleClose() {
        delegate?.aiInspectorOverlayDidRequestDismiss(self)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let parent = superview else { return }
        let point = gesture.location(in: parent)

        let wasHidden = isHidden
        isHidden = true
        let target = parent.hitTest(point, with: nil)
        isHidden = wasHidden

        guard let target, target !== parent else {
            hideHighlightAndCard()
            return
        }

        if banner.frame.contains(gesture.location(in: self)) {
            return
        }

        inspect(view: target)
    }

    // MARK: - Inspect
    private func inspect(view: UIView) {
        let payload = InspectionPayload(target: view)
        showHighlight(over: view)
        detailCard.configure(payload: payload)
        detailCard.isHidden = false
        UIView.animate(withDuration: 0.18) {
            self.detailCard.alpha = 1
        }
    }

    private func showHighlight(over view: UIView) {
        let rect = view.convert(view.bounds, to: self)
        highlightView.frame = rect.insetBy(dx: -2, dy: -2)
        highlightView.isHidden = false
        highlightView.alpha = 0
        UIView.animate(withDuration: 0.18) {
            self.highlightView.alpha = 1
        }
    }

    private func hideHighlightAndCard() {
        UIView.animate(withDuration: 0.15) {
            self.highlightView.alpha = 0
            self.detailCard.alpha = 0
        } completion: { _ in
            self.highlightView.isHidden = true
            self.detailCard.isHidden = true
        }
    }
}

// MARK: - Inspection Payload
struct InspectionPayload {
    let typeName: String
    let accessibilityIdentifier: String?
    let displayText: String?
    let localizationKey: String?

    init(target: UIView) {
        self.typeName = String(describing: type(of: target))
        self.accessibilityIdentifier = target.accessibilityIdentifier

        let text = Self.extractText(from: target)
        self.displayText = text
        if let text, !text.isEmpty {
            self.localizationKey = LocalizationManager.key(forDisplayString: text)
        } else {
            self.localizationKey = nil
        }
    }

    private static func extractText(from view: UIView) -> String? {
        if let label = view as? UILabel {
            return label.text
        }
        if let button = view as? UIButton {
            return button.configuration?.title ?? button.titleLabel?.text
        }
        if let textField = view as? UITextField {
            return textField.text?.isEmpty == false ? textField.text : textField.placeholder
        }
        if let textView = view as? UITextView {
            return textView.text
        }
        for subview in view.subviews {
            if let text = extractText(from: subview), !text.isEmpty {
                return text
            }
        }
        return nil
    }
}
