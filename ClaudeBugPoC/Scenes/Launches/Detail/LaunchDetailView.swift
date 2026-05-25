//
//  LaunchDetailView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit
import Kingfisher

protocol LaunchDetailViewDelegate: AnyObject {
    func launchDetailView(_ view: LaunchDetailView, didTapLink kind: LaunchDetailView.LinkKind)
}

final class LaunchDetailView: LayoutableView {

    enum LinkKind {
        case webcast
        case article
        case wikipedia
    }

    // MARK: - Public
    weak var delegate: LaunchDetailViewDelegate?

    // MARK: - UI
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.backgroundColor = .clear
        return sv
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 32, right: 16)
        return stack
    }()

    private lazy var patchImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .secondarySystemBackground
        iv.layer.cornerRadius = 16
        iv.clipsToBounds = true
        return iv
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private lazy var statusBadge: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        return label
    }()

    private lazy var statusContainer: UIView = {
        let view = UIView()
        view.addSubview(statusBadge)
        statusBadge.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalTo(28)
            make.width.greaterThanOrEqualTo(100)
        }
        return view
    }()

    private lazy var detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private lazy var detailsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(14)
        }
        return view
    }()

    private lazy var linksStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()

    private lazy var webcastButton = makeLinkButton(title: "Yayını İzle", icon: "play.rectangle.fill", color: .systemRed, kind: .webcast)
    private lazy var articleButton = makeLinkButton(title: "Makale", icon: "newspaper.fill", color: .systemBlue, kind: .article)
    private lazy var wikipediaButton = makeLinkButton(title: "Wikipedia", icon: "book.fill", color: .systemGray, kind: .wikipedia)

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .systemBackground
        addSubview(scrollView)
        addSubview(loadingIndicator)
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(patchImageView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(statusContainer)
        contentStack.addArrangedSubview(detailsContainer)

        linksStack.addArrangedSubview(webcastButton)
        linksStack.addArrangedSubview(articleButton)
        linksStack.addArrangedSubview(wikipediaButton)
        contentStack.addArrangedSubview(linksStack)

        contentStack.setCustomSpacing(8, after: titleLabel)
        contentStack.setCustomSpacing(8, after: subtitleLabel)

        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.frameLayoutGuide.snp.width)
        }
        patchImageView.snp.makeConstraints { make in
            make.height.equalTo(240)
        }
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    // MARK: - Public
    func setLoading(_ loading: Bool) {
        loading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
        scrollView.isHidden = loading
    }

    func configure(with launch: Launch) {
        titleLabel.text = launch.name
        var subtitleParts: [String] = []
        if let flight = launch.flightNumber {
            subtitleParts.append("Uçuş #\(flight)")
        }
        subtitleParts.append(launch.fullDisplayDate)
        subtitleLabel.text = subtitleParts.joined(separator: " • ")

        statusBadge.text = " \(launch.statusText) "
        switch launch.success {
        case true: statusBadge.backgroundColor = .systemGreen
        case false: statusBadge.backgroundColor = .systemRed
        default: statusBadge.backgroundColor = .systemGray
        }

        let patch = launch.links.patch?.large ?? launch.links.patch?.small
        patchImageView.kf.setImage(
            with: patch.flatMap(URL.init(string:)),
            placeholder: UIImage(systemName: "airplane.circle")
        )

        if let details = launch.details, !details.isEmpty {
            detailsLabel.text = details
            detailsContainer.isHidden = false
        } else {
            detailsContainer.isHidden = true
        }

        webcastButton.isHidden = launch.links.webcast == nil
        articleButton.isHidden = launch.links.article == nil
        wikipediaButton.isHidden = launch.links.wikipedia == nil
    }

    // MARK: - Builders
    private func makeLinkButton(title: String, icon: String, color: UIColor, kind: LinkKind) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.tintColor = .white
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        button.tag = {
            switch kind {
            case .webcast: return 0
            case .article: return 1
            case .wikipedia: return 2
            }
        }()
        button.addTarget(self, action: #selector(linkTapped(_:)), for: .touchUpInside)
        button.snp.makeConstraints { $0.height.equalTo(48) }
        return button
    }

    @objc private func linkTapped(_ sender: UIButton) {
        let kind: LinkKind
        switch sender.tag {
        case 0: kind = .webcast
        case 1: kind = .article
        default: kind = .wikipedia
        }
        delegate?.launchDetailView(self, didTapLink: kind)
    }
}
