//
//  Accessible.swift
//  ClaudeBugPoC
//

import UIKit

/// Conform to `Accessible` to auto-generate `accessibilityIdentifier`s from property names.
protocol Accessible {
    func generateAccessibilityIdentifiers()
}

extension Accessible {

    /// Reflects over `self` and assigns each `UIView` child an `accessibilityIdentifier`
    /// of the form `"\(type(of: self)).\(propertyName)"`. DEBUG only.
    func generateAccessibilityIdentifiers() {
#if DEBUG
        let mirror = Mirror(reflecting: self)

        for child in mirror.children {
            if let view = child.value as? UIView,
               let identifier = child
                .label?
                .replacingOccurrences(of: ".storage", with: "")
                .replacingOccurrences(of: "$__lazy_storage_$_", with: "") {
                view.accessibilityIdentifier = "\(type(of: self)).\(identifier)"
            }
        }
#endif
    }
}
