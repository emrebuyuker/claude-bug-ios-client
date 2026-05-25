//
//  Layouting.swift
//  ClaudeBugPoC
//

import UIKit

/// Conform to `Layouting` in `UIViewController` that layouts a `Layoutable` `UIView`.
protocol Layouting: AnyObject {

    /// `Layoutable` view type associated with this controller.
    associatedtype ViewType: UIView & Layoutable

    /// `view` downcast to `ViewType`.
    var layoutableView: ViewType { get }
}

extension Layouting where Self: UIViewController {

    var layoutableView: ViewType {
        guard let aView = view as? ViewType else {
            fatalError("view property has not been initialized yet, or not initialized as \(ViewType.self).")
        }
        return aView
    }
}
