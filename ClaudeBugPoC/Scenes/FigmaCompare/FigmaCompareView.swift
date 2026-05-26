//
//  FigmaCompareView.swift
//  ClaudeBugPoC
//

import UIKit
import SnapKit

// MARK: - Delegate
protocol FigmaCompareViewDelegate: AnyObject {
    func figmaCompareView(_ view: FigmaCompareView, didTapSubmitWith url: String)
    func figmaCompareViewDidTapReset(_ view: FigmaCompareView)
    func figmaCompareViewDidTapCreateJira(_ view: FigmaCompareView)
    func figmaCompareView(_ view: FigmaCompareView, didTapEditFor differenceId: UUID)
}

// MARK: - View
// swiftlint:disable:next type_body_length
final class FigmaCompareView: LayoutableView {

    // MARK: - Public
    weak var delegate: FigmaCompareViewDelegate?

    // MARK: - Input UI
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = LocalizationKey.View.FigmaCompare.urlInputTitle.localize
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = LocalizationKey.View.FigmaCompare.urlInputSubtitle.localize
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var urlTextField: UITextField = {
        let field = UITextField()
        field.placeholder = LocalizationKey.View.FigmaCompare.urlInputPlaceholder.localize
        field.font = .systemFont(ofSize: 15, weight: .regular)
        field.backgroundColor = .secondarySystemBackground
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 0.5
        field.layer.borderColor = UIColor.separator.cgColor
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.keyboardType = .URL
        field.returnKeyType = .go
        field.clearButtonMode = .whileEditing
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        field.leftView = padding
        field.leftViewMode = .always
        field.delegate = self
        return field
    }()

    private lazy var submitButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = LocalizationKey.View.FigmaCompare.submitButton.localize
        config.baseBackgroundColor = .systemIndigo
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(handleSubmit), for: .touchUpInside)
        return button
    }()

    private lazy var screenInfoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var inputContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(urlTextField)
        view.addSubview(submitButton)
        view.addSubview(screenInfoLabel)
        return view
    }()

    // MARK: - Loading UI
    private lazy var loadingSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .systemIndigo
        spinner.hidesWhenStopped = false
        return spinner
    }()

    private lazy var loadingLabel: UILabel = {
        let label = UILabel()
        label.text = LocalizationKey.View.FigmaCompare.loadingMessage.localize
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private lazy var loadingContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.addSubview(loadingSpinner)
        view.addSubview(loadingLabel)
        view.isHidden = true
        return view
    }()

    // MARK: - Result UI
    private lazy var resultHeaderLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        label.text = LocalizationKey.View.FigmaCompare.resultTitle.localize
        return label
    }()

    private lazy var resultDetectedScreenLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var resultSummaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var resultMetadataLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var resultEmptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = LocalizationKey.View.FigmaCompare.resultEmpty.localize
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    private lazy var resetButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = LocalizationKey.View.FigmaCompare.cancelButton.localize
        config.baseForegroundColor = .systemIndigo
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(handleReset), for: .touchUpInside)
        return button
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 0, bottom: 16, right: 0)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.register(FigmaDifferenceCell.self, forCellWithReuseIdentifier: FigmaDifferenceCell.reuseIdentifier)
        return cv
    }()

    private lazy var createJiraButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = LocalizationKey.View.FigmaCompare.createJiraButton.localize
        config.image = UIImage(systemName: "ladybug.fill")
        config.imagePadding = 8
        config.baseBackgroundColor = .systemIndigo
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(handleCreateJira), for: .touchUpInside)
        return button
    }()

    private lazy var jiraButtonContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        let separator = UIView()
        separator.backgroundColor = .separator
        view.addSubview(separator)
        view.addSubview(createJiraButton)
        separator.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(0.5)
        }
        createJiraButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(12)
        }
        return view
    }()

    private lazy var resultContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.addSubview(resultHeaderLabel)
        view.addSubview(resultDetectedScreenLabel)
        view.addSubview(resultSummaryLabel)
        view.addSubview(resultMetadataLabel)
        view.addSubview(resetButton)
        view.addSubview(collectionView)
        view.addSubview(resultEmptyLabel)
        view.addSubview(jiraButtonContainer)
        view.isHidden = true
        return view
    }()

    // MARK: - Action Loading Overlay
    private lazy var actionOverlaySpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.hidesWhenStopped = false
        return spinner
    }()

    private lazy var actionOverlayLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var actionOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        view.isHidden = true
        view.addSubview(actionOverlaySpinner)
        view.addSubview(actionOverlayLabel)
        actionOverlaySpinner.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-20)
        }
        actionOverlayLabel.snp.makeConstraints { make in
            make.top.equalTo(actionOverlaySpinner.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(40)
        }
        return view
    }()

    // MARK: - Error UI
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .systemRed
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var errorRetryButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = LocalizationKey.View.FigmaCompare.cancelButton.localize
        config.baseForegroundColor = .systemIndigo
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(handleReset), for: .touchUpInside)
        return button
    }()

    private lazy var errorContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.addSubview(errorLabel)
        view.addSubview(errorRetryButton)
        view.isHidden = true
        return view
    }()

    // MARK: - Layoutable
    func setupViews() {
        backgroundColor = .systemBackground
        addSubview(inputContainer)
        addSubview(loadingContainer)
        addSubview(resultContainer)
        addSubview(errorContainer)
        addSubview(actionOverlay)
        generateAccessibilityIdentifiers()
    }

    func setupLayout() {
        layoutInputContainer()
        layoutLoadingContainer()
        layoutResultContainer()
        layoutErrorContainer()
        layoutActionOverlay()
    }

    private func layoutActionOverlay() {
        actionOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Layout Helpers
    private func layoutInputContainer() {
        inputContainer.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        urlTextField.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(48)
        }
        submitButton.snp.makeConstraints { make in
            make.top.equalTo(urlTextField.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
        screenInfoLabel.snp.makeConstraints { make in
            make.top.equalTo(submitButton.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }
    }

    private func layoutLoadingContainer() {
        loadingContainer.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }
        loadingSpinner.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-20)
        }
        loadingLabel.snp.makeConstraints { make in
            make.top.equalTo(loadingSpinner.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }
    }

    private func layoutResultContainer() {
        resultContainer.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }
        resultHeaderLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().inset(20)
            make.trailing.lessThanOrEqualTo(resetButton.snp.leading).offset(-8)
        }
        resetButton.snp.makeConstraints { make in
            make.centerY.equalTo(resultHeaderLabel)
            make.trailing.equalToSuperview().inset(20)
        }
        resultDetectedScreenLabel.snp.makeConstraints { make in
            make.top.equalTo(resultHeaderLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        resultSummaryLabel.snp.makeConstraints { make in
            make.top.equalTo(resultDetectedScreenLabel.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        resultMetadataLabel.snp.makeConstraints { make in
            make.top.equalTo(resultSummaryLabel.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(resultMetadataLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(jiraButtonContainer.snp.top)
        }
        jiraButtonContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        resultEmptyLabel.snp.makeConstraints { make in
            make.center.equalTo(collectionView)
            make.leading.trailing.equalToSuperview().inset(40)
        }
    }

    private func layoutErrorContainer() {
        errorContainer.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }
        errorLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview().offset(-20)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        errorRetryButton.snp.makeConstraints { make in
            make.top.equalTo(errorLabel.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
    }

    // MARK: - Public — Configure
    func configureInput(screenIdentifier: String) {
        let format = LocalizationKey.View.FigmaCompare.detectedScreenFormat.localize
        screenInfoLabel.text = format.replacing("screen", with: screenIdentifier)
    }

    func showInput() {
        inputContainer.isHidden = false
        loadingContainer.isHidden = true
        loadingSpinner.stopAnimating()
        resultContainer.isHidden = true
        errorContainer.isHidden = true
        urlTextField.becomeFirstResponder()
    }

    func showLoading() {
        inputContainer.isHidden = true
        urlTextField.resignFirstResponder()
        loadingContainer.isHidden = false
        loadingSpinner.startAnimating()
        resultContainer.isHidden = true
        errorContainer.isHidden = true
    }

    func showResult(_ response: FigmaCompareResponse, screenIdentifier: String) {
        inputContainer.isHidden = true
        loadingContainer.isHidden = true
        loadingSpinner.stopAnimating()
        resultContainer.isHidden = false
        errorContainer.isHidden = true

        let detected = response.detectedScreen ?? screenIdentifier
        let detectedFormat = LocalizationKey.View.FigmaCompare.detectedScreenFormat.localize
        resultDetectedScreenLabel.text = detectedFormat.replacing("screen", with: detected)

        resultSummaryLabel.text = response.summary
        resultSummaryLabel.isHidden = (response.summary?.isEmpty ?? true)

        let metadataFormat = LocalizationKey.View.FigmaCompare.metadataFormat.localize
        resultMetadataLabel.text = metadataFormat
            .replacing("iterations", with: response.iterations)
            .replacing("inputTokens", with: response.inputTokens)
            .replacing("outputTokens", with: response.outputTokens)
            .replacing("cost", with: String(format: "%.4f", response.estimatedCostUsd))

        resultEmptyLabel.isHidden = !response.differences.isEmpty
        createJiraButton.isEnabled = !response.differences.isEmpty
        createJiraButton.alpha = response.differences.isEmpty ? 0.5 : 1.0
        collectionView.reloadData()
    }

    func showActionLoading(_ message: String) {
        actionOverlayLabel.text = message
        actionOverlay.isHidden = false
        actionOverlaySpinner.startAnimating()
        bringSubviewToFront(actionOverlay)
    }

    func hideActionLoading() {
        actionOverlay.isHidden = true
        actionOverlaySpinner.stopAnimating()
    }

    func showError(_ message: String) {
        inputContainer.isHidden = true
        loadingContainer.isHidden = true
        loadingSpinner.stopAnimating()
        resultContainer.isHidden = true
        errorContainer.isHidden = false
        urlTextField.resignFirstResponder()
        errorLabel.text = message
    }

    func setCollectionDataSource(_ dataSource: UICollectionViewDataSource & UICollectionViewDelegateFlowLayout) {
        collectionView.dataSource = dataSource
        collectionView.delegate = dataSource
    }

    // MARK: - Actions
    @objc private func handleSubmit() {
        let text = urlTextField.text ?? ""
        delegate?.figmaCompareView(self, didTapSubmitWith: text)
    }

    @objc private func handleReset() {
        urlTextField.text = ""
        delegate?.figmaCompareViewDidTapReset(self)
    }

    @objc private func handleCreateJira() {
        delegate?.figmaCompareViewDidTapCreateJira(self)
    }
}

// MARK: - FigmaDifferenceCellDelegate
extension FigmaCompareView: FigmaDifferenceCellDelegate {
    func figmaDifferenceCellDidTapEdit(_ cell: FigmaDifferenceCell, differenceId: UUID) {
        delegate?.figmaCompareView(self, didTapEditFor: differenceId)
    }
}

// MARK: - UITextFieldDelegate
extension FigmaCompareView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        handleSubmit()
        return true
    }
}
