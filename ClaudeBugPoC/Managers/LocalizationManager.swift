//
//  LocalizationManager.swift
//  ClaudeBugPoC
//

import Foundation

enum LocalizationManager {

    // MARK: - Reverse Map
    /// Maps a resolved display string back to the localization key that produced it.
    /// Populated lazily by `getKey` / `getKeyOrDefault`. Used by the inspector overlay
    /// to decide whether a label's text came from `Localizable.strings` or from the backend.
    private static var displayStringToKey: [String: String] = [:]
    private static let mapQueue = DispatchQueue(label: "ClaudeBugPoC.LocalizationManager.map")

    // MARK: - Public
    /// Resolves a localization key to its display string.
    /// Chain: `NSLocalizedString` (reads `Localizable.strings`) → `DefaultStrings.fallback` → key itself.
    static func getKey(key: String) -> String {
        let value = resolve(key: key, logMisses: true)
        record(displayString: value, forKey: key)
        return value
    }

    /// Same as `getKey` but does not log on miss — use for dynamic keys
    /// (status suffixes, unit codes) where misses are expected.
    static func getKeyOrDefault(key: String) -> String {
        let value = resolve(key: key, logMisses: false)
        if !value.isEmpty {
            record(displayString: value, forKey: key)
        }
        return value
    }

    /// Returns the localization key that produced `displayString`, if any.
    /// Used by the inspector overlay — `nil` means the text is not from `Localizable.strings`
    /// (e.g. backend payload, hardcoded string).
    static func key(forDisplayString displayString: String) -> String? {
        return mapQueue.sync { displayStringToKey[displayString] }
    }

    // MARK: - Private
    private static func resolve(key: String, logMisses: Bool) -> String {
        let localized = NSLocalizedString(key, comment: "")
        if localized != key, !localized.isEmpty {
            return localized
        }

        if let fallback = DefaultStrings(rawValue: key)?.fallback {
            return fallback
        }

        #if DEBUG
        if logMisses {
            print("⚠️ Missing localization for key: \(key)")
        }
        #endif
        return logMisses ? key : ""
    }

    private static func record(displayString: String, forKey key: String) {
        mapQueue.async {
            displayStringToKey[displayString] = key
        }
    }
}
