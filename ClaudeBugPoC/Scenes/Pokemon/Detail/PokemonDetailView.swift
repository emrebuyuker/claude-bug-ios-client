//
//  PokemonDetailView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit
import Kingfisher

final class PokemonDetailView: LayoutableView {

    // MARK: - UI
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = .clear
        sv.alwaysBounceVertical = true
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

    private lazy var artworkImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .secondarySystemBackground
        iv.layer.cornerRadius = 16
        iv.clipsToBounds = true
        return iv
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private lazy var typesStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .equalCentering
        return stack
    }()

    private lazy var physicalStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        return stack
    }()

    private lazy var heightCard = makeInfoCard(title: "Boy")
    private lazy var weightCard = makeInfoCard(title: "Ağırlık")

    private lazy var statsTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.text = "Statlar"
        return label
    }()

    private lazy var statsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
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

        contentStack.addArrangedSubview(artworkImageView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(typesStack)
        physicalStack.addArrangedSubview(heightCard.container)
        physicalStack.addArrangedSubview(weightCard.container)
        contentStack.addArrangedSubview(physicalStack)
        contentStack.addArrangedSubview(statsTitleLabel)
        contentStack.addArrangedSubview(statsStack)

        contentStack.setCustomSpacing(4, after: titleLabel)
        contentStack.setCustomSpacing(20, after: subtitleLabel)
        contentStack.setCustomSpacing(20, after: physicalStack)

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
        artworkImageView.snp.makeConstraints { make in
            make.height.equalTo(260)
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

    func configure(with detail: PokemonDetail) {
        titleLabel.text = detail.displayName
        subtitleLabel.text = detail.formattedId
        artworkImageView.kf.setImage(with: detail.sprites.bestArtwork.flatMap(URL.init(string:)))
        heightCard.valueLabel.text = String(format: "%.1f m", detail.heightInMeters)
        weightCard.valueLabel.text = String(format: "%.1f kg", detail.weightInKilograms)

        typesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for slot in detail.types.sorted(by: { $0.slot < $1.slot }) {
            typesStack.addArrangedSubview(makeTypeBadge(name: slot.type.name))
        }

        statsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for stat in detail.stats {
            statsStack.addArrangedSubview(makeStatRow(name: stat.displayName, value: stat.baseStat))
        }
    }

    // MARK: - Builders
    private func makeInfoCard(title: String) -> (container: UIView, valueLabel: UILabel) {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.text = title
        titleLabel.textAlignment = .center

        let valueLabel = UILabel()
        valueLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        container.snp.makeConstraints { make in
            make.height.equalTo(64)
        }
        return (container, valueLabel)
    }

    private func makeTypeBadge(name: String) -> UIView {
        let label = UILabel()
        label.text = name.capitalized
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center

        let container = UIView()
        container.backgroundColor = colorForType(name)
        container.layer.cornerRadius = 12
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(6)
            make.leading.trailing.equalToSuperview().inset(14)
        }
        return container
    }

    private func makeStatRow(name: String, value: Int) -> UIView {
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        nameLabel.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.text = "\(value)"
        valueLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .right

        let progress = UIProgressView(progressViewStyle: .default)
        progress.progress = Float(min(value, 200)) / 200.0
        progress.progressTintColor = .systemBlue
        progress.trackTintColor = .tertiarySystemFill
        progress.layer.cornerRadius = 3
        progress.clipsToBounds = true

        let topRow = UIStackView(arrangedSubviews: [nameLabel, valueLabel])
        topRow.axis = .horizontal
        topRow.spacing = 8

        let container = UIStackView(arrangedSubviews: [topRow, progress])
        container.axis = .vertical
        container.spacing = 4

        progress.snp.makeConstraints { make in
            make.height.equalTo(6)
        }
        return container
    }

    private func colorForType(_ name: String) -> UIColor {
        switch name {
        case "fire": return .systemOrange
        case "water": return .systemBlue
        case "grass": return .systemGreen
        case "electric": return .systemYellow
        case "psychic": return .systemPink
        case "ice": return .systemTeal
        case "dragon": return .systemIndigo
        case "dark": return .darkGray
        case "fairy": return .systemPurple
        case "poison": return .purple
        case "ground": return .brown
        case "rock": return .systemBrown
        case "bug": return .systemMint
        case "ghost": return .systemIndigo
        case "steel": return .systemGray
        case "fighting": return .systemRed
        case "flying": return .systemCyan
        default: return .systemGray2
        }
    }
}
