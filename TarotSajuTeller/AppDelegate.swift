//
//  AppDelegate.swift
//  TarotSajuTeller
//
//  Created by Gucci on 2/15/26.
//

import UIKit
import Kingfisher

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        ImageCache.default.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024 // 100MB
        ImageCache.default.diskStorage.config.sizeLimit = 300 * 1024 * 1024 // 300MB
        ImageCache.default.diskStorage.config.expiration = .days(30)

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
