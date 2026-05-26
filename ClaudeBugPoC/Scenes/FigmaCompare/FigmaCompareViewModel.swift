//
//  FigmaCompareViewModel.swift
//  ClaudeBugPoC
//

import Foundation
import FirebaseFunctions

// MARK: - State
enum FigmaCompareState {
    case input
    case loading
    case result(FigmaCompareResponse)
    case error(String)
}

// MARK: - Action State
enum FigmaCompareActionState {
    case idle
    case creatingJira
    case jiraSuccess(ticketKey: String, ticketUrl: String)
    case applyingFix(differenceId: UUID)
    case fixSuccess(prUrl: String, prNumber: Int, filePath: String)
    case actionFailed(message: String)
}

// MARK: - Delegate
protocol FigmaCompareViewModelDelegate: AnyObject {
    func figmaCompareViewModelDidUpdateState(_ viewModel: FigmaCompareViewModel)
    func figmaCompareViewModelDidUpdateActionState(_ viewModel: FigmaCompareViewModel)
}

// MARK: - ViewModel
final class FigmaCompareViewModel {

    // MARK: - Public
    weak var delegate: FigmaCompareViewModelDelegate?
    private(set) var state: FigmaCompareState = .input
    private(set) var actionState: FigmaCompareActionState = .idle
    let screenIdentifier: String

    // MARK: - Private
    private let functions: Functions
    private static let callableTimeout: TimeInterval = 240
    private static let fixCallableTimeout: TimeInterval = 300

    // MARK: - Init
    init(
        screenIdentifier: String,
        functions: Functions = Functions.functions(region: "us-central1")
    ) {
        self.screenIdentifier = screenIdentifier
        self.functions = functions
    }

    // MARK: - Actions
    func submit(figmaURL: String) {
        let trimmed = figmaURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidFigmaURL(trimmed) else {
            updateState(.error(LocalizationKey.View.FigmaCompare.errorInvalidURL.localize))
            return
        }

        updateState(.loading)
        callFigmaCompare(figmaURL: trimmed)
    }

    func reset() {
        updateState(.input)
    }

    func currentDifferences() -> [FigmaDifference] {
        guard case .result(let response) = state else { return [] }
        return response.differences
    }

    func difference(withId id: UUID) -> FigmaDifference? {
        return currentDifferences().first { $0.id == id }
    }

    func createJiraTicket() {
        guard case .result(let response) = state else { return }
        guard !response.differences.isEmpty else { return }
        if case .creatingJira = actionState { return }
        if case .applyingFix = actionState { return }

        updateActionState(.creatingJira)

        let bugDescription = formatJiraDescription(
            screenIdentifier: response.detectedScreen ?? screenIdentifier,
            summary: response.summary,
            differences: response.differences
        )
        let payload: [String: Any] = ["bugDescription": bugDescription]
        let callable = functions.httpsCallable("createBugTicket")
        callable.timeoutInterval = Self.callableTimeout
        callable.call(payload) { [weak self] result, error in
            guard let self else { return }

            if let error {
                let nsError = error as NSError
                self.updateActionState(.actionFailed(message: nsError.localizedDescription))
                return
            }

            guard let data = result?.data as? [String: Any],
                  let ticketKey = data["ticketKey"] as? String,
                  let ticketUrl = data["ticketUrl"] as? String else {
                self.updateActionState(.actionFailed(
                    message: LocalizationKey.View.FigmaCompare.unexpectedResponse.localize
                ))
                return
            }

            self.updateActionState(.jiraSuccess(ticketKey: ticketKey, ticketUrl: ticketUrl))
        }
    }

    func applyFix(forDifferenceId id: UUID) {
        guard let difference = difference(withId: id) else { return }
        if case .applyingFix = actionState { return }
        if case .creatingJira = actionState { return }

        updateActionState(.applyingFix(differenceId: id))

        var payload: [String: Any] = [
            "screenIdentifier": screenIdentifier,
            "differenceTitle": difference.title,
            "differenceDetail": difference.detail,
            "differenceCategory": difference.category.rawValue
        ]
        if let hint = difference.codeHint {
            payload["codeHint"] = hint
        }

        let callable = functions.httpsCallable("figmaApplyFix")
        callable.timeoutInterval = Self.fixCallableTimeout
        callable.call(payload) { [weak self] result, error in
            guard let self else { return }

            if let error {
                let nsError = error as NSError
                self.updateActionState(.actionFailed(message: nsError.localizedDescription))
                return
            }

            guard let data = result?.data as? [String: Any],
                  let prUrl = data["prUrl"] as? String,
                  let prNumber = data["prNumber"] as? Int,
                  let filePath = data["filePath"] as? String else {
                self.updateActionState(.actionFailed(
                    message: LocalizationKey.View.FigmaCompare.unexpectedResponse.localize
                ))
                return
            }

            self.updateActionState(.fixSuccess(prUrl: prUrl, prNumber: prNumber, filePath: filePath))
        }
    }

    func acknowledgeActionResult() {
        updateActionState(.idle)
    }

    // MARK: - Formatting
    private func formatJiraDescription(
        screenIdentifier: String,
        summary: String?,
        differences: [FigmaDifference]
    ) -> String {
        var lines: [String] = []
        lines.append("Figma karşılaştırması \"\(screenIdentifier)\" ekranı için aşağıdaki farkları döndürdü.")
        if let summary = summary, !summary.isEmpty {
            lines.append("")
            lines.append("Özet: \(summary)")
        }
        lines.append("")
        lines.append("Farklar (\(differences.count)):")
        for (index, diff) in differences.enumerated() {
            lines.append("")
            let categoryLabel = diff.category.localizationKey.localize
            let severityLabel = diff.severity.localizationKey.localize
            lines.append("\(index + 1). [\(categoryLabel) · \(severityLabel)] \(diff.title)")
            lines.append(diff.detail)
            if let hint = diff.codeHint, !hint.isEmpty {
                lines.append("Kod ipucu: \(hint)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Validation
    private func isValidFigmaURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased() else {
            return false
        }
        guard host.contains("figma.com") else { return false }
        let pathComponents = url.pathComponents
        let hasFileSegment = pathComponents.contains("design") || pathComponents.contains("file")
        let hasNodeId = url.query?.contains("node-id=") ?? false
        return hasFileSegment && hasNodeId
    }

    // MARK: - Network
    private func callFigmaCompare(figmaURL: String) {
        let payload: [String: Any] = [
            "figmaURL": figmaURL,
            "screenIdentifier": screenIdentifier
        ]
        let callable = functions.httpsCallable("figmaCompare")
        callable.timeoutInterval = Self.callableTimeout
        callable.call(payload) { [weak self] result, error in
            guard let self else { return }

            if let error {
                let nsError = error as NSError
                let message = LocalizationKey.View.FigmaCompare.errorFormat.localize
                    .replacing("message", with: nsError.localizedDescription)
                self.updateState(.error(message))
                return
            }

            guard let data = result?.data as? [String: Any],
                  let response = FigmaCompareResponse(dictionary: data) else {
                self.updateState(.error(LocalizationKey.View.FigmaCompare.unexpectedResponse.localize))
                return
            }

            self.updateState(.result(response))
        }
    }

    // MARK: - State
    private func updateState(_ newState: FigmaCompareState) {
        state = newState
        delegate?.figmaCompareViewModelDidUpdateState(self)
    }

    private func updateActionState(_ newState: FigmaCompareActionState) {
        actionState = newState
        delegate?.figmaCompareViewModelDidUpdateActionState(self)
    }
}
