//
//  AppDelegate.swift
//  ClaudeBugPoC
//
//  Created by Emre Büyüker on 24.05.2026.
//

import UIKit
import FirebaseCore
import FirebaseAppCheck

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // App Check provider MUST be set before FirebaseApp.configure().
        // Otherwise the first Functions call goes out without an App Check token
        // and gets rejected once enforcement is on.
        //
        // NOTE: As of now App Check enforcement is OFF on the Cloud Function
        // side (no paid Apple Developer account → can't register App Attest
        // in Firebase Console). The factory still runs and generates tokens,
        // but the backend doesn't verify them yet. To activate end-to-end:
        //   1. Get an Apple Developer account, register App Attest in
        //      Firebase Console → App Check with the real Team ID.
        //   2. Add `enforceAppCheck: true` to the askClaude onCall options.
        //   3. Redeploy the function.
        AppCheck.setAppCheckProviderFactory(ClaudeBugAppCheckProviderFactory())

        FirebaseApp.configure()

        // Swizzle viewDidAppear so every screen transition lands in the bug
        // report's activity timeline.
        UIViewController.installScreenTracking()

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

/// Picks an App Check provider per build configuration.
///
/// - DEBUG (simulator / development builds):
///     `AppCheckDebugProvider` — prints a debug token to the Xcode console on
///     first launch. Copy it into Firebase Console → App Check → Apps →
///     "Manage debug tokens" so the backend treats this client as trusted.
/// - Release on real devices (iOS 14+):
///     `AppAttestProvider` — uses Apple's App Attest to prove the app binary
///     and device are genuine.
/// - Release on older devices (iOS 11–13 fallback):
///     `DeviceCheckProvider` — Apple's older device-integrity API.
final class ClaudeBugAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        return AppCheckDebugProvider(app: app)
        #else
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        }
        return DeviceCheckProvider(app: app)
        #endif
    }
}

