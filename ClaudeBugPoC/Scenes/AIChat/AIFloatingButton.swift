//
//  AIFloatingButton.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

// MARK: - Delegate
protocol AIFloatingButtonDelegate: AnyObject {
    func aiFloatingButtonDidTap(_ button: AIFloatingButton)
}

// MARK: - Button
final class AIFloatingButton: LayoutableView {

    // MARK: - Public
    weak var delegate: AIFloatingButtonDelegate?

    static let size: CGFloat = 56
    static let edgeMargin: CGFloat = 16

    // MARK: - UI
    private lazy var iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(
            systemName: "sparkles",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        )
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = false
        return iv
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .systemIndigo
        frame = CGRect(origin: .zero, size: CGSize(width: Self.size, height: Self.size))
        layer.cornerRadius = Self.size / 2
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 10
        accessibilityLabel = "AI Asistan"

        addSubview(iconImageView)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(26)
        }
    }

    // MARK: - Gestures
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let parent = superview else { return }
        switch gesture.state {
        case .changed:
            let translation = gesture.translation(in: parent)
            let proposed = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
            center = clamp(point: proposed, in: parent, snapHorizontally: false)
            gesture.setTranslation(.zero, in: parent)
        case .ended, .cancelled:
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.6,
                options: [.allowUserInteraction]
            ) {
                self.center = self.clamp(point: self.center, in: parent, snapHorizontally: true)
            }
        default:
            break
        }
    }

    @objc private func handleTap() {
        UIView.animate(
            withDuration: 0.08,
            animations: { self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92) },
            completion: { _ in
                UIView.animate(withDuration: 0.12) { self.transform = .identity }
            }
        )
        delegate?.aiFloatingButtonDidTap(self)
    }

    // MARK: - Position
    private func clamp(point: CGPoint, in parent: UIView, snapHorizontally: Bool) -> CGPoint {
        let safe = parent.safeAreaInsets
        let half = bounds.width / 2
        let minX = safe.left + half + Self.edgeMargin
        let maxX = parent.bounds.width - safe.right - half - Self.edgeMargin
        let minY = safe.top + half + Self.edgeMargin
        let maxY = parent.bounds.height - safe.bottom - half - Self.edgeMargin

        var targetX = max(minX, min(maxX, point.x))
        let targetY = max(minY, min(maxY, point.y))

        if snapHorizontally {
            let mid = parent.bounds.width / 2
            targetX = targetX < mid ? minX : maxX
        }
        return CGPoint(x: targetX, y: targetY)
    }
}
