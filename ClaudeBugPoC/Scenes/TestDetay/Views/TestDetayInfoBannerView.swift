//
//  TestDetayInfoBannerView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

final class TestDetayInfoBannerView: LayoutableView {

    // MARK: - UI
    private lazy var iconImageView: UIImageView = {
        let image = UIImage(systemName: "exclamationmark.circle.fill")?
            .withRenderingMode(.alwaysTemplate)
        let iv = UIImageView(image: image)
        iv.tintColor = UIColor(red: 1.00, green: 0.67, blue: 0.00, alpha: 1.0)
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = UIColor(red: 1.00, green: 0.97, blue: 0.92, alpha: 1.0)
        layer.cornerRadius = 26
        layer.masksToBounds = true
        addSubview(iconImageView)
        addSubview(messageLabel)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(12)
            make.size.equalTo(16)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalTo(iconImageView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(12)
        }
    }

    // MARK: - Configure
    func configure(with text: String) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        messageLabel.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0),
                .paragraphStyle: style
            ]
        )
    }
}
