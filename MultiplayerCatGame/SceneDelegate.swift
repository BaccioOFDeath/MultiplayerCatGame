// SceneDelegate.swift
import UIKit
import SpriteKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let win = UIWindow(windowScene: windowScene)
        let skView = CustomSKView(frame: win.bounds)
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
        win.rootViewController = UIViewController()
        win.rootViewController?.view = skView
        window = win
        win.makeKeyAndVisible()

        let menu = MenuScene(size: skView.bounds.size)
        menu.scaleMode = .resizeFill
        skView.presentScene(menu)
    }
}
