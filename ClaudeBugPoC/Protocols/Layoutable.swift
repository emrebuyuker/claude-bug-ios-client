//
//  Layoutable.swift
//  ClaudeBugPoC
//

import UIKit

/// Conform to `Layoutable` in `UIView` classes to setup its subviews and autolayout.
protocol Layoutable: AnyObject {

    /// Setup the view and its subviews here. Add subviews, set `backgroundColor`, etc.
    func setupViews()

    /// Add layout (SnapKit) code here.
    func setupLayout()

    /// Preferred spacing for autolayout. Default: `UIScreen.main.bounds.size.minDimension * 0.054`.
    var preferredSpacing: CGFloat { get }
}

// MARK: - Default implementation for UIView
extension Layoutable where Self: UIView {

    var preferredSpacing: CGFloat {
        return UIScreen.main.bounds.size.minDimension * 0.054
    }

    /// Factory that constructs the view and calls `setupViews()` + `setupLayout()`.
    ///
    /// - Parameters:
    ///   - setupViews: whether to call `setupViews`. Default: `true`.
    ///   - setupLayout: whether to call `setupLayout`. Default: `true`.
    /// - Returns: A fully configured instance of `Self`.
    static func create(setupViews: Bool = true, setupLayout: Bool = true) -> Self {
        let view = Self()
        if setupViews {
            view.setupViews()
        }
        if setupLayout {
            view.setupLayout()
        }
        return view
    }
}
