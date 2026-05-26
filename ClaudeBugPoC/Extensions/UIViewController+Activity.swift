//
//  UIViewController+Activity.swift
//  ClaudeBugPoC
//

import UIKit
import ObjectiveC.runtime

extension UIViewController {

    /// Swizzles `viewDidAppear(_:)` so every screen transition is recorded by
    /// ActivityRecorder. Call once from AppDelegate before scenes attach.
    static func installScreenTracking() {
        struct Once { static var done = false }
        guard !Once.done else { return }
        Once.done = true

        let original = #selector(UIViewController.viewDidAppear(_:))
        let swizzled = #selector(UIViewController.cb_activityViewDidAppear(_:))

        guard let originalMethod = class_getInstanceMethod(UIViewController.self, original),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzled) else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc private func cb_activityViewDidAppear(_ animated: Bool) {
        // Calls original viewDidAppear via swapped IMP.
        cb_activityViewDidAppear(animated)

        let name = String(describing: type(of: self))
        guard UIViewController.shouldRecordScreen(name) else { return }
        ActivityRecorder.shared.recordScreen(name)
    }

    /// Filters out container / system / Firebase view controllers — only app-level
    /// screens carry signal for bug context.
    private static func shouldRecordScreen(_ className: String) -> Bool {
        if className.hasPrefix("UI") { return false }         // UINavigationController, UITabBarController, etc.
        if className.hasPrefix("_UI") { return false }        // private UIKit internals
        if className.hasPrefix("SF") { return false }         // SafariServices
        if className.hasPrefix("FIR") { return false }        // Firebase
        if className.hasPrefix("FBL") { return false }        // Firebase internal
        if className.contains("Hosting") { return false }     // SwiftUI hosting
        return true
    }
}
