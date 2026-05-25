//
//  LayoutableCollectionViewCell.swift
//  ClaudeBugPoC
//

import UIKit

/// Layoutable `UICollectionViewCell`.
///
/// Aliases to:
///  - `UICollectionViewCell`
///
/// Conforms to:
///  - `Layoutable`
///  - `Reusable`
///  - `Accessible`
typealias LayoutableCollectionViewCell = UICollectionViewCell & Layoutable & Reusable & Accessible
