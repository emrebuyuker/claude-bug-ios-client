//
//  Reusable.swift
//  ClaudeBugPoC
//

import UIKit

/// Conform to `Reusable` in reusable views like `UITableViewCell` or `UICollectionViewCell`.
protocol Reusable {

    /// Unique reuse identifier — defaults to `String(describing: type(of: self))`.
    static var reuseIdentifier: String { get }
}

// MARK: - Default implementation for UITableViewCell
extension Reusable where Self: UITableViewCell {
    static var reuseIdentifier: String { String(describing: type(of: self)) }
}

// MARK: - Default implementation for UICollectionViewCell
extension Reusable where Self: UICollectionViewCell {
    static var reuseIdentifier: String { String(describing: type(of: self)) }
}

// MARK: - Default implementation for UITableViewHeaderFooterView
extension Reusable where Self: UITableViewHeaderFooterView {
    static var reuseIdentifier: String { String(describing: type(of: self)) }
}

// MARK: - Default implementation for UICollectionReusableView
extension Reusable where Self: UICollectionReusableView {
    static var reuseIdentifier: String { String(describing: type(of: self)) }
}
