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
}

// MARK: - FigmaCompareViewModelDelegate
extension FigmaCompareViewController: FigmaCompareViewModelDelegate {
    func figmaCompareViewModelDidUpdateState(_ viewModel: FigmaCompareViewModel) {
        applyState()
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
        var total: CGFloat = 12 + 18 + 6 + titleHeight + 4 + detailHeight + 12
        if let hint = difference.codeHint, !hint.isEmpty {
            let hintHeight = hint.heightForFont(
                .monospacedSystemFont(ofSize: 12, weight: .regular),
                width: textWidth
            )
            total += 8 + hintHeight + 8
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
