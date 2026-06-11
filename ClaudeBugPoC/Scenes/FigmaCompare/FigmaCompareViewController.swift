//
//  FigmaCompareViewController.swift
//  ClaudeBugPoC
//

import UIKit
import PhotosUI
import UniformTypeIdentifiers

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

    func figmaCompareViewDidTapPickImage(_ view: FigmaCompareView) {
        view.endEditing(true)
        presentImageSourceSheet(from: view)
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

// MARK: - Image Picking
extension FigmaCompareViewController {
    private func presentImageSourceSheet(from sourceView: UIView) {
        let sheet = UIAlertController(
            title: LocalizationKey.View.FigmaCompare.pickImageSheetTitle.localize,
            message: nil,
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(
            title: LocalizationKey.View.FigmaCompare.pickImagePhotos.localize,
            style: .default
        ) { [weak self] _ in
            self?.presentPhotoPicker()
        })
        sheet.addAction(UIAlertAction(
            title: LocalizationKey.View.FigmaCompare.pickImageFiles.localize,
            style: .default
        ) { [weak self] _ in
            self?.presentDocumentPicker()
        })
        sheet.addAction(UIAlertAction(
            title: LocalizationKey.View.FigmaCompare.cancelButton.localize,
            style: .cancel
        ))
        // iPad: action sheet bir popover olarak sunulur, kaynak gerekir.
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = CGRect(
                x: sourceView.bounds.midX,
                y: sourceView.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        present(sheet, animated: true)
    }

    private func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentDocumentPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.png, .jpeg, .image])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func handlePickedImage(_ image: UIImage) {
        guard let encoded = Self.encodeForUpload(image) else {
            presentImageReadError()
            return
        }
        viewModel.submit(
            imageBase64: encoded.data.base64EncodedString(),
            mediaType: encoded.mediaType
        )
    }

    private func presentImageReadError() {
        let alert = UIAlertController(
            title: LocalizationKey.View.Common.errorAlertTitle.localize,
            message: LocalizationKey.View.FigmaCompare.imageReadError.localize,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: LocalizationKey.View.Common.okButton.localize,
            style: .default
        ))
        present(alert, animated: true)
    }

    // MARK: - Encoding
    private static let maxImageDimension: CGFloat = 1568
    private static let maxUploadBytes = 5 * 1024 * 1024

    /// Görseli ~1568px uzun kenara küçültüp önce PNG dener; 5MB'ı aşarsa JPEG'e
    /// düşer. Anthropic görsel başına ~5MB ve ~1568px uzun kenar önerir.
    private static func encodeForUpload(_ image: UIImage) -> (data: Data, mediaType: String)? {
        let resized = resized(image, maxDimension: maxImageDimension)
        if let png = resized.pngData(), png.count <= maxUploadBytes {
            return (png, "image/png")
        }
        var quality: CGFloat = 0.8
        while quality >= 0.4 {
            if let jpeg = resized.jpegData(compressionQuality: quality), jpeg.count <= maxUploadBytes {
                return (jpeg, "image/jpeg")
            }
            quality -= 0.2
        }
        return nil
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - PHPickerViewControllerDelegate
extension FigmaCompareViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self.handlePickedImage(image)
            }
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension FigmaCompareViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            presentImageReadError()
            return
        }
        handlePickedImage(image)
    }
}
