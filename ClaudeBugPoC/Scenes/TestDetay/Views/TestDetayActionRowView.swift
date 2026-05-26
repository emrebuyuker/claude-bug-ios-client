//
//  TestDetayActionRowView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

protocol TestDetayActionRowViewDelegate: AnyObject {
    func testDetayActionRowViewDidTap(_ row: TestDetayActionRowView)
}

final class TestDetayActionRowView: LayoutableView {

    // MARK: - Constants
    private enum Const {
        static let labelColor = UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)
        static let mutedColor = UIColor(red: 0.51, green: 0.51, blue: 0.59, alpha: 1.0)
        static let chevronColor = UIColor(red: 0.71, green: 0.71, blue: 0.76, alpha: 1.0)
        static let amberBg = UIColor(red: 1.00, green: 0.97, blue: 0.92, alpha: 1.0)
        static let japanRed = UIColor(red: 0.85, green: 0.00, blue: 0.15, alpha: 1.0)
        static let japanCircleBg = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
    }

    enum Style {
        case install
        case repurchase
        case otherPlans

        var iconName: String? {
            switch self {
            case .install: return "square.and.arrow.down"
            case .repurchase: return "arrow.triangle.2.circlepath"
            case .otherPlans: return nil
            }
        }

        var backgroundColor: UIColor {
            switch self {
            case .install: return Const.amberBg
            case .repurchase, .otherPlans: return .white
            }
        }

        var usesJapanFlag: Bool {
            return self == .otherPlans
        }
    }

    // MARK: - Public
    weak var delegate: TestDetayActionRowViewDelegate?

    // MARK: - Private
    private var style: Style = .install

    // MARK: - UI
    private lazy var iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = Const.mutedColor
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private lazy var japanFlagView: UIView = {
        let outer = UIView()
        outer.backgroundColor = Const.japanCircleBg
        outer.layer.cornerRadius = 12
        outer.isHidden = true

        let dot = UIView()
        dot.backgroundColor = Const.japanRed
        dot.layer.cornerRadius = 5
        outer.addSubview(dot)
        dot.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(10)
        }
        return outer
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = Const.labelColor
        return label
    }()

    private lazy var chevronImageView: UIImageView = {
        let image = UIImage(systemName: "chevron.right")?
            .withRenderingMode(.alwaysTemplate)
        let iv = UIImageView(image: image)
        iv.tintColor = Const.chevronColor
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .white
        layer.cornerRadius = 26
        layer.masksToBounds = true
        addSubview(iconImageView)
        addSubview(japanFlagView)
        addSubview(titleLabel)
        addSubview(chevronImageView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)

        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        japanFlagView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
        }
        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
    }

    // MARK: - Configure
    func configure(title: String, style: Style) {
        self.style = style
        titleLabel.text = title
        backgroundColor = style.backgroundColor

        if style.usesJapanFlag {
            iconImageView.isHidden = true
            japanFlagView.isHidden = false
        } else {
            iconImageView.isHidden = false
            japanFlagView.isHidden = true
            if let name = style.iconName {
                iconImageView.image = UIImage(systemName: name)?
                    .withRenderingMode(.alwaysTemplate)
            }
        }
    }

    // MARK: - Actions
    @objc private func didTap() {
        delegate?.testDetayActionRowViewDidTap(self)
    }
}
