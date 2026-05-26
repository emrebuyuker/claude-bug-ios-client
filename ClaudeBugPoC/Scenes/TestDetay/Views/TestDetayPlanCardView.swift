//
//  TestDetayPlanCardView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

final class TestDetayPlanCardView: LayoutableView {

    // MARK: - Constants
    private enum Const {
        static let labelColor = UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)
        static let mutedColor = UIColor(red: 0.51, green: 0.51, blue: 0.59, alpha: 1.0)
        static let accent = UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0)
        static let badgeBg = UIColor(red: 0.94, green: 0.97, blue: 1.00, alpha: 1.0)
        static let providerRed = UIColor(red: 0.93, green: 0.19, blue: 0.14, alpha: 1.0)
    }

    // MARK: - UI
    private lazy var providerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = Const.providerRed
        return label
    }()

    private lazy var badgeDot: UIView = {
        let view = UIView()
        view.backgroundColor = Const.accent
        view.layer.cornerRadius = 3
        return view
    }()

    private lazy var badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = Const.accent
        return label
    }()

    private lazy var badgeView: UIView = {
        let view = UIView()
        view.backgroundColor = Const.badgeBg
        view.layer.cornerRadius = 12
        view.addSubview(badgeDot)
        view.addSubview(badgeLabel)
        badgeDot.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.size.equalTo(6)
        }
        badgeLabel.snp.makeConstraints { make in
            make.leading.equalTo(badgeDot.snp.trailing).offset(6)
            make.trailing.equalToSuperview().inset(10)
            make.centerY.equalToSuperview()
            make.top.equalToSuperview().offset(5)
            make.bottom.equalToSuperview().inset(5)
        }
        return view
    }()

    private lazy var headerRow: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.addSubview(providerLabel)
        view.addSubview(badgeView)
        providerLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        badgeView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.height.equalTo(24)
        }
        return view
    }()

    private lazy var dataRow = makeSpecRow(
        iconName: "arrow.up.arrow.down",
        title: "Data"
    )

    private lazy var validityRow = makeSpecRow(
        iconName: "calendar",
        title: "Validity"
    )

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [headerRow, dataRow.row, validityRow.row])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        return stack
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .white
        layer.cornerRadius = 26
        layer.masksToBounds = true
        addSubview(contentStack)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(16)
        }
        headerRow.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
        dataRow.row.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
        validityRow.row.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
    }

    // MARK: - Configure
    func configure(provider: String, badge: String, data: String, validity: String) {
        providerLabel.text = provider
        badgeLabel.text = badge
        dataRow.valueLabel.text = data
        validityRow.valueLabel.text = validity
    }

    // MARK: - Helpers
    private func makeSpecRow(
        iconName: String,
        title: String
    ) -> (row: UIView, valueLabel: UILabel) {
        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.tintColor = Const.mutedColor
        icon.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = Const.labelColor

        let valueLabel = UILabel()
        valueLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        valueLabel.textColor = Const.labelColor
        valueLabel.textAlignment = .right

        let container = UIView()
        container.backgroundColor = .clear
        container.addSubview(icon)
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)

        icon.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(20)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
        }
        valueLabel.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }
        return (container, valueLabel)
    }
}
