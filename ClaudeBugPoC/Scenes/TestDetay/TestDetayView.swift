//
//  TestDetayView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

protocol TestDetayViewDelegate: AnyObject {
    func testDetayViewDidTapBack()
    func testDetayViewDidTapInfo()
    func testDetayView(_ view: TestDetayView, didSelectActionAt index: Int)
}

final class TestDetayView: LayoutableView {

    // MARK: - Constants
    private enum Const {
        static let bgColor = UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)
        static let labelColor = UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)
        static let separatorColor = UIColor(red: 0.90, green: 0.92, blue: 0.96, alpha: 1.0)
        static let horizontalInset: CGFloat = 16
    }

    // MARK: - Public
    weak var delegate: TestDetayViewDelegate?

    // MARK: - UI — Top Bar
    private lazy var backIconImageView: UIImageView = {
        let image = UIImage(systemName: "chevron.left")?
            .withRenderingMode(.alwaysTemplate)
        let iv = UIImageView(image: image)
        iv.tintColor = Const.labelColor
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private lazy var backLabel: UILabel = {
        let label = UILabel()
        label.text = "Back"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = Const.labelColor
        return label
    }()

    private lazy var backButton: UIControl = {
        let control = UIControl()
        control.backgroundColor = .clear
        control.addSubview(backIconImageView)
        control.addSubview(backLabel)
        backIconImageView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        backLabel.snp.makeConstraints { make in
            make.leading.equalTo(backIconImageView.snp.trailing).offset(2)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        control.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        return control
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = Const.labelColor
        label.textAlignment = .center
        return label
    }()

    private lazy var infoButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "info.circle.fill")?
            .withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = UIColor(red: 0.51, green: 0.51, blue: 0.59, alpha: 1.0)
        button.addTarget(self, action: #selector(didTapInfo), for: .touchUpInside)
        return button
    }()

    private lazy var topBarSeparator: UIView = {
        let view = UIView()
        view.backgroundColor = Const.separatorColor
        return view
    }()

    private lazy var topBar: UIView = {
        let view = UIView()
        view.backgroundColor = Const.bgColor
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(infoButton)
        view.addSubview(topBarSeparator)
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Const.horizontalInset)
            make.centerY.equalToSuperview()
            make.height.equalTo(32)
        }
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        infoButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Const.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        topBarSeparator.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
        return view
    }()

    // MARK: - UI — Body
    private lazy var infoBannerView = TestDetayInfoBannerView.create()
    private lazy var planCardView = TestDetayPlanCardView.create()
    private lazy var noticeCardView = TestDetayNoticeCardView.create()

    private lazy var actionsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        return stack
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            infoBannerView,
            planCardView,
            noticeCardView,
            actionsStack
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.setCustomSpacing(16, after: noticeCardView)
        return stack
    }()

    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.backgroundColor = .clear
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 24, right: 0)
        scroll.addSubview(contentStack)
        return scroll
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = Const.bgColor
        addSubview(topBar)
        addSubview(scrollView)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        topBar.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(56)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide)
        }
        contentStack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(Const.horizontalInset)
            make.trailing.equalToSuperview().inset(Const.horizontalInset)
            make.width.equalToSuperview().offset(-Const.horizontalInset * 2)
        }
        infoBannerView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(72)
        }
        planCardView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(124)
        }
        noticeCardView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(112)
        }
    }

    // MARK: - Configure
    func configure(plan: EsimPlanSummary, actions: [EsimActionItem]) {
        titleLabel.text = plan.countryTitle
        infoBannerView.configure(with: plan.bannerText)
        planCardView.configure(
            provider: plan.providerName,
            providerAssetName: plan.providerLogoAssetName,
            badge: plan.badgeText,
            data: plan.dataAmount,
            validity: plan.validity
        )
        noticeCardView.configure(with: plan.noticeText)
        rebuildActions(actions)
    }

    // MARK: - Actions
    @objc private func didTapBack() {
        delegate?.testDetayViewDidTapBack()
    }

    @objc private func didTapInfo() {
        delegate?.testDetayViewDidTapInfo()
    }

    // MARK: - Helpers
    private func rebuildActions(_ actions: [EsimActionItem]) {
        actionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, action) in actions.enumerated() {
            let row = TestDetayActionRowView.create()
            row.tag = index
            row.delegate = self
            row.configure(title: action.title, style: action.type.rowStyle)
            row.snp.makeConstraints { make in
                make.height.equalTo(56)
            }
            actionsStack.addArrangedSubview(row)
        }
    }
}

// MARK: - TestDetayActionRowViewDelegate
extension TestDetayView: TestDetayActionRowViewDelegate {
    func testDetayActionRowViewDidTap(_ row: TestDetayActionRowView) {
        delegate?.testDetayView(self, didSelectActionAt: row.tag)
    }
}

// MARK: - Action Type → Row Style
private extension EsimActionType {
    var rowStyle: TestDetayActionRowView.Style {
        switch self {
        case .install: return .install
        case .repurchase: return .repurchase
        case .otherPlans: return .otherPlans
        }
    }
}
