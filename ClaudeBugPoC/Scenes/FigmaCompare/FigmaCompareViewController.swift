//
//  FigmaCompareViewController.swift
//  ClaudeBugPoC
//

import UIKit

final class FigmaCompareViewController: LayoutingViewController {

    // MARK: - Properties
    typealias ViewType = FigmaCompareView
    private let viewModel: FigmaCompareViewModel

    // MARK: - Init
    init(viewModel: FigmaCompareViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle
    override func loadView() {
        super.loadView()
        view = ViewType.create()
        view.accessibilityIdentifier = "figmaCompareViewController"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LocalizationKey.View.FigmaCompare.navigationTitle.localize
        viewModel.delegate = self
        layoutableView.delegate = self
        layoutableView.setCollectionDataSource(self)
        layoutableView.configureInput(screenIdentifier: viewModel.screenIdentifier)
        applyState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if case .input = viewModel.state {
            layoutableView.showInput()
        }
    }

    // MARK: - State
    private func applyState() {
        switch viewModel.state {
        case .input:
            layoutableView.showInput()
        case .loading:
            layoutableView.showLoading()
        case .result(let response):
            layoutableView.showResult(response, screenIdentifier: viewModel.screenIdentifier)
        case .error(let message):
            layoutableView.showError(message)
        }
    }

    // MARK: - Helpers
    private var sortedDifferences: [FigmaDifference] {
        guard case .result(let response) = viewModel.state else { return [] }
        return response.differences.sorted { $0.severity.order < $1.severity.order }
    }
}

// MARK: - FigmaCompareViewDelegate
extension FigmaCompareViewController: FigmaCompareViewDelegate {
    func figmaCompareView(_ view: FigmaCompareView, didTapSubmitWith url: String) {
        viewModel.submit(figmaURL: url)
    }

    func figmaCompareViewDidTapReset(_ view: FigmaCompareView) {
        viewModel.reset()
    }

    func figmaCompareViewDidTapCreateJira(_ view: FigmaCompareView) {
        viewModel.createJiraTicket()
    }

    func figmaCompareView(_ view: FigmaCompareView, didTapEditFor differenceId: UUID) {
        viewModel.applyFix(forDifferenceId: differenceId)
    }
}

// MARK: - FigmaCompareViewModelDelegate
extension FigmaCompareViewController: FigmaCompareViewModelDelegate {
    func figmaCompareViewModelDidUpdateState(_ viewModel: FigmaCompareViewModel) {
        applyState()
    }

    func figmaCompareViewModelDidUpdateActionState(_ viewModel: FigmaCompareViewModel) {
        applyActionState()
    }

    private func applyActionState() {
        switch viewModel.actionState {
        case .idle:
            layoutableView.hideActionLoading()
        case .creatingJira:
            layoutableView.showActionLoading(
                LocalizationKey.View.FigmaCompare.creatingJiraMessage.localize
            )
        case .applyingFix:
            layoutableView.showActionLoading(
                LocalizationKey.View.FigmaCompare.applyingFixMessage.localize
            )
        case .jiraSuccess(let ticketKey, let ticketUrl):
            layoutableView.hideActionLoading()
            presentJiraSuccess(ticketKey: ticketKey, ticketUrl: ticketUrl)
        case .fixSuccess(let prUrl, let prNumber, let filePath):
            layoutableView.hideActionLoading()
            presentFixSuccess(prUrl: prUrl, prNumber: prNumber, filePath: filePath)
        case .actionFailed(let message):
            layoutableView.hideActionLoading()
            presentActionError(message: message)
        }
    }

    private func presentJiraSuccess(ticketKey: String, ticketUrl: String) {
        let title = LocalizationKey.View.FigmaCompare.jiraSuccessTitle.localize
        let messageFormat = LocalizationKey.View.FigmaCompare.jiraSuccessMessage.localize
        let message = messageFormat.replacing("ticketKey", with: ticketKey)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(
            title: LocalizationKey.View.FigmaCompare.openButton.localize,
            style: .default
        ) { [weak self] _ in
            self?.openURL(ticketUrl)
            self?.viewModel.acknowledgeActionResult()
        })
        alert.addAction(UIAlertAction(
            title: LocalizationKey.View.Common.okButton.localize,
            style: .cancel
        ) { [weak self] _ in
            self?.viewModel.acknowledgeActionResult()
        })
        present(alert, animated: true)
    }

    private func presentFixSuccess(prUrl: String, prNumber: Int, filePath: String) {
        let title = LocalizationKey.View.FigmaCompare.fixSuccessTitle.localize
        let messageFormat = LocalizationKey.View.FigmaCompare.fixSuccessMessage.localize
        let message = messageFormat
            .replacing("prNumber", with: prNumber)
            .replacing("filePath", with: filePath)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(
            title: LocalizationKey.View.FigmaCompare.openButton.localize,
            style: .default
        ) { [weak self] _ in
            self?.openURL(prUrl)
            self?.viewModel.acknowledgeActionResult()
        })
        alert.addAction(UIAlertAction(
            title: LocalizationKey.View.Common.okButton.localize,
            style: .cancel
        ) { [weak self] _ in
            self?.viewModel.acknowledgeActionResult()
        })
        present(alert, animated: true)
    }

    private func presentActionError(message: String) {
        let alert = UIAlertController(
            title: LocalizationKey.View.Common.errorAlertTitle.localize,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: LocalizationKey.View.Common.okButton.localize,
            style: .default
        ) { [weak self] _ in
            self?.viewModel.acknowledgeActionResult()
        })
        present(alert, animated: true)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - UICollectionViewDataSource & UICollectionViewDelegateFlowLayout
extension FigmaCompareViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sortedDifferences.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FigmaDifferenceCell.reuseIdentifier,
            for: indexPath
        ) as? FigmaDifferenceCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: sortedDifferences[indexPath.item])
        cell.delegate = layoutableView
        if case .applyingFix = viewModel.actionState {
            cell.setEditEnabled(false)
        } else if case .creatingJira = viewModel.actionState {
            cell.setEditEnabled(false)
        } else {
            cell.setEditEnabled(true)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = collectionView.bounds.width
        guard width > 0 else { return CGSize(width: 0, height: 80) }
        let difference = sortedDifferences[indexPath.item]
        let height = estimatedHeight(for: difference, width: width)
        return CGSize(width: width, height: height)
    }

    private func estimatedHeight(for difference: FigmaDifference, width: CGFloat) -> CGFloat {
        let horizontalPadding: CGFloat = 14 * 2
        let textWidth = width - horizontalPadding
        let titleHeight = difference.title.heightForFont(
            .systemFont(ofSize: 16, weight: .semibold),
            width: textWidth
        )
        let detailHeight = difference.detail.heightForFont(
            .systemFont(ofSize: 14, weight: .regular),
            width: textWidth
        )
        // top(12) + category(18) + 6 + title + 4 + detail + 8 + (hint or 0) + 10 + edit(32) + 10
        var total: CGFloat = 12 + 18 + 6 + titleHeight + 4 + detailHeight + 8 + 10 + 32 + 10
        if let hint = difference.codeHint, !hint.isEmpty {
            let hintHeight = hint.heightForFont(
                .monospacedSystemFont(ofSize: 12, weight: .regular),
                width: textWidth
            )
            total += hintHeight
        }
        return total
    }
}

// MARK: - String Sizing
private extension String {
    func heightForFont(_ font: UIFont, width: CGFloat) -> CGFloat {
        guard !isEmpty else { return 0 }
        let constraint = CGSize(width: width, height: .greatestFiniteMagnitude)
        let bounding = (self as NSString).boundingRect(
            with: constraint,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(bounding.height)
    }
}
