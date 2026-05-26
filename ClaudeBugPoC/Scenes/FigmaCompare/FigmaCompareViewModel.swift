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

// MARK: - Delegate
protocol FigmaCompareViewModelDelegate: AnyObject {
    func figmaCompareViewModelDidUpdateState(_ viewModel: FigmaCompareViewModel)
}

// MARK: - ViewModel
final class FigmaCompareViewModel {

    // MARK: - Public
    weak var delegate: FigmaCompareViewModelDelegate?
    private(set) var state: FigmaCompareState = .input
    let screenIdentifier: String

    // MARK: - Private
    private let functions: Functions
    private static let callableTimeout: TimeInterval = 240

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
}
