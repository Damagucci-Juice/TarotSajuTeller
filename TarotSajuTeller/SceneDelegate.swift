//
//  SceneDelegate.swift
//  TarotSajuTeller
//
//  Created by Gucci on 2/15/26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions) {
            guard let windowScene = (scene as? UIWindowScene) else { return }
            let window = UIWindow(windowScene: windowScene)
            let view = MainViewController()
            let nav = UINavigationController(rootViewController: view)
            window.rootViewController = nav
            self.window = window
            self.window?.makeKeyAndVisible()
        }
}
