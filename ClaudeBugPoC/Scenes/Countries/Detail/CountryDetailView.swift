//
//  CountryDetailView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit
import Kingfisher

protocol CountryDetailViewDelegate: AnyObject {
    func countryDetailViewDidTapMap(_ view: CountryDetailView)
}

final class CountryDetailView: LayoutableView {

    // MARK: - Public
    weak var delegate: CountryDetailViewDelegate?

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
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 32, right: 16)
        return stack
    }()

    private lazy var flagImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .secondarySystemBackground
        iv.layer.cornerRadius = 8
        iv.clipsToBounds = true
        iv.layer.borderColor = UIColor.separator.cgColor
        iv.layer.borderWidth = 0.5
        return iv
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var officialLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var mapsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(LocalizationKey.View.Countries.openMap.localize, for: .normal)
        button.setImage(UIImage(systemName: "map.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        button.addTarget(self, action: #selector(mapsTapped), for: .touchUpInside)
        return button
    }()

    private lazy var infoStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.backgroundColor = .secondarySystemBackground
        stack.layer.cornerRadius = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        return stack
    }()

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

        contentStack.addArrangedSubview(flagImageView)
        contentStack.addArrangedSubview(nameLabel)
        contentStack.addArrangedSubview(officialLabel)
        contentStack.addArrangedSubview(mapsButton)
        contentStack.addArrangedSubview(infoStack)

        contentStack.setCustomSpacing(8, after: nameLabel)

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
        flagImageView.snp.makeConstraints { make in
            make.height.equalTo(180)
        }
        mapsButton.snp.makeConstraints { make in
            make.height.equalTo(48)
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

    func configure(with detail: CountryDetail) {
        nameLabel.text = detail.name.common
        officialLabel.text = detail.name.official
        flagImageView.kf.setImage(with: (detail.flags.png ?? detail.flags.svg).flatMap(URL.init(string:)))

        mapsButton.isHidden = detail.maps?.googleMaps == nil

        infoStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        addRow(label: LocalizationKey.View.Countries.capital.localize, value: detail.capital?.joined(separator: ", ") ?? "—")
        addRow(label: LocalizationKey.View.Countries.region.localize, value: [detail.region, detail.subregion].compactMap { $0 }.joined(separator: " / "))
        addRow(label: LocalizationKey.View.Countries.population.localize, value: detail.formattedPopulation)
        addRow(label: LocalizationKey.View.Countries.area.localize, value: detail.formattedArea)
        addRow(label: LocalizationKey.View.Countries.languages.localize, value: detail.languagesText)
        addRow(label: LocalizationKey.View.Countries.currency.localize, value: detail.currenciesText)
        if let timezones = detail.timezones, !timezones.isEmpty {
            addRow(label: LocalizationKey.View.Countries.timezone.localize, value: timezones.joined(separator: ", "))
        }
        if let borders = detail.borders, !borders.isEmpty {
            addRow(label: LocalizationKey.View.Countries.borders.localize, value: borders.joined(separator: ", "))
        }
    }

    // MARK: - Actions
    @objc private func mapsTapped() {
        delegate?.countryDetailViewDidTapMap(self)
    }

    // MARK: - Builders
    private func addRow(label: String, value: String) {
        infoStack.addArrangedSubview(makeInfoRow(label: label, value: value))
    }

    private func makeInfoRow(label: String, value: String) -> UIView {
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 13, weight: .medium)
        labelView.textColor = .secondaryLabel

        let valueView = UILabel()
        valueView.text = value
        valueView.font = .systemFont(ofSize: 15, weight: .regular)
        valueView.textColor = .label
        valueView.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [labelView, valueView])
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }
}
