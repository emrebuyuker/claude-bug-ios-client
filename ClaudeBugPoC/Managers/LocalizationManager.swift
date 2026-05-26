//
//  LocalizationManager.swift
//  ClaudeBugPoC
//

import Foundation

enum LocalizationManager {

    // MARK: - Public
    /// Resolves a localization key to its display string.
    /// Chain: `NSLocalizedString` (reads `Localizable.strings`) → `DefaultStrings.fallback` → key itself.
    static func getKey(key: String) -> String {
        let localized = NSLocalizedString(key, comment: "")
        if localized != key, !localized.isEmpty {
            return localized
        }

        if let fallback = DefaultStrings(rawValue: key)?.fallback {
            return fallback
        }

        #if DEBUG
        print("⚠️ Missing localization for key: \(key)")
        #endif
        return key
    }

    /// Same as `getKey` but does not log on miss — use for dynamic keys
    /// (status suffixes, unit codes) where misses are expected.
    static func getKeyOrDefault(key: String) -> String {
        let localized = NSLocalizedString(key, comment: "")
        if localized != key, !localized.isEmpty {
            return localized
        }
        return DefaultStrings(rawValue: key)?.fallback ?? ""
    }
}
