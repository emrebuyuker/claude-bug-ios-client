//
//  TestDetayNoticeCardView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

final class TestDetayNoticeCardView: LayoutableView {

    // MARK: - UI
    private lazy var iconImageView: UIImageView = {
        let image = UIImage(systemName: "info.circle.fill")?
            .withRenderingMode(.alwaysTemplate)
        let iv = UIImageView(image: image)
        iv.tintColor = UIColor(red: 0.51, green: 0.51, blue: 0.59, alpha: 1.0)
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .white
        layer.cornerRadius = 26
        layer.masksToBounds = true
        addSubview(iconImageView)
        addSubview(messageLabel)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(16)
            make.size.equalTo(16)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.leading.equalTo(iconImageView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(16)
        }
    }

    // MARK: - Configure
    func configure(with text: String) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        messageLabel.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0),
                .paragraphStyle: style
            ]
        )
    }
}
