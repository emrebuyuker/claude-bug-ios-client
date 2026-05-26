//
//  String+Localization.swift
//  ClaudeBugPoC
//

import UIKit

extension String {

    // MARK: - Localize
    /// Resolves `self` as a localization key through `LocalizationManager`.
    var localize: String {
        return LocalizationManager.getKey(key: self)
    }

    // MARK: - Placeholder Replacement
    /// Replaces `{placeholder}` token with the given value. If the bracket form
    /// is missing, falls back to replacing the bare placeholder. Useful for
    /// format-style localized strings like `"Uçuş #{number}"`.
    func replacing(_ placeholder: String, with value: Any?) -> String {
        let bracketed = "{\(placeholder)}"
        if self.contains(bracketed) {
            return self.replacingOccurrences(of: bracketed, with: "\(value ?? bracketed)")
        }
        if self.contains(placeholder) {
            return self.replacingOccurrences(of: placeholder, with: "\(value ?? placeholder)")
        }
        return self
    }
}

extension String {

    // MARK: - UI Helpers
    /// Localize and assign to a UILabel.
    func UILocalize(_ item: UILabel) {
        item.text = isEmpty ? "" : localize
    }

    /// Localize and assign to a UITextView.
    func UILocalize(_ item: UITextView) {
        item.text = isEmpty ? "" : localize
    }

    /// Localize and assign to a UITextField.
    func UILocalize(_ item: UITextField) {
        item.text = isEmpty ? "" : localize
    }

    /// Localize and assign to a UIButton's normal-state title.
    func UILocalize(_ item: UIButton) {
        item.setTitle(isEmpty ? "" : localize, for: .normal)
    }
}
