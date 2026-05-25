//
//  MealDetailView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit
import Kingfisher

protocol MealDetailViewDelegate: AnyObject {
    func mealDetailViewDidTapYoutube(_ view: MealDetailView)
}

final class MealDetailView: LayoutableView {

    // MARK: - Public
    weak var delegate: MealDetailViewDelegate?

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
        stack.spacing = 20
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 32, right: 16)
        return stack
    }()

    private lazy var heroImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemBackground
        return iv
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private lazy var metaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var youtubeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("YouTube'da İzle", for: .normal)
        button.setImage(UIImage(systemName: "play.rectangle.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        button.addTarget(self, action: #selector(youtubeTapped), for: .touchUpInside)
        return button
    }()

    private lazy var ingredientsHeader = makeSectionHeader(title: "Malzemeler")
    private lazy var ingredientsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()

    private lazy var instructionsHeader = makeSectionHeader(title: "Hazırlanışı")
    private lazy var instructionsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        return label
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
        scrollView.addSubview(heroImageView)
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(metaLabel)
        contentStack.addArrangedSubview(youtubeButton)
        contentStack.addArrangedSubview(ingredientsHeader)
        contentStack.addArrangedSubview(ingredientsStack)
        contentStack.addArrangedSubview(instructionsHeader)
        contentStack.addArrangedSubview(instructionsLabel)

        contentStack.setCustomSpacing(8, after: titleLabel)
        contentStack.setCustomSpacing(8, after: ingredientsHeader)
        contentStack.setCustomSpacing(8, after: instructionsHeader)

        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        heroImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(self)
            make.height.equalTo(260)
        }
        contentStack.snp.makeConstraints { make in
            make.top.equalTo(heroImageView.snp.bottom).offset(20)
            make.leading.trailing.bottom.equalToSuperview()
            make.width.equalTo(self)
        }
        youtubeButton.snp.makeConstraints { make in
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

    func configure(with detail: MealDetail) {
        titleLabel.text = detail.name
        heroImageView.kf.setImage(with: detail.thumbnailURL.flatMap(URL.init(string:)))
        instructionsLabel.text = detail.instructions ?? "Tarif yok."

        let metaParts = [detail.category, detail.area].compactMap { $0 }.filter { !$0.isEmpty }
        metaLabel.text = metaParts.joined(separator: " • ")
        metaLabel.isHidden = metaParts.isEmpty

        let hasYoutube = detail.youtubeURL?.isEmpty == false
        youtubeButton.isHidden = !hasYoutube

        ingredientsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in detail.ingredients {
            ingredientsStack.addArrangedSubview(makeIngredientRow(name: item.ingredient, measure: item.measure))
        }
    }

    // MARK: - Actions
    @objc private func youtubeTapped() {
        delegate?.mealDetailViewDidTapYoutube(self)
    }

    // MARK: - Builders
    private func makeSectionHeader(title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }

    private func makeIngredientRow(name: String, measure: String) -> UIView {
        let bullet = UILabel()
        bullet.text = "•"
        bullet.font = .systemFont(ofSize: 18, weight: .bold)
        bullet.textColor = .systemBlue

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 15, weight: .medium)
        nameLabel.textColor = .label

        let measureLabel = UILabel()
        measureLabel.text = measure
        measureLabel.font = .systemFont(ofSize: 13, weight: .regular)
        measureLabel.textColor = .secondaryLabel
        measureLabel.textAlignment = .right
        measureLabel.setContentHuggingPriority(.required, for: .horizontal)
        measureLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [bullet, nameLabel, measureLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center

        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 8
        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))
        }
        return container
    }
}
