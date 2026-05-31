// VisualFactory.swift
// Shared visual helpers for the MultiplayerCatGame
import SpriteKit
import UIKit

enum VisualFactory {

    // MARK: - Fonts
    static let titleFont  = "AvenirNext-Heavy"
    static let bodyFont   = "AvenirNext-DemiBold"
    static let labelFont  = "AvenirNext-Regular"

    // MARK: - Colors
    static let accentOrange = UIColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 1)
    static let accentPurple = UIColor(red: 0.55, green: 0.2, blue: 0.9, alpha: 1)
    static let hudBg        = UIColor(white: 0, alpha: 0.55)
    static let buttonBg     = UIColor(red: 0.15, green: 0.15, blue: 0.25, alpha: 0.92)
    static let buttonBorder = UIColor(red: 0.55, green: 0.2, blue: 0.9, alpha: 1)

    // MARK: - Background gradient (two layered SKSpriteNodes)
    static func addGradientBackground(to scene: SKScene, topColor: UIColor, bottomColor: UIColor) {
        guard let grad = gradientImage(size: scene.size, top: topColor, bottom: bottomColor) else { return }
        let bg = SKSpriteNode(texture: SKTexture(image: grad))
        bg.position = CGPoint(x: scene.size.width/2, y: scene.size.height/2)
        bg.zPosition = -100
        scene.addChild(bg)
    }

    private static func gradientImage(size: CGSize, top: UIColor, bottom: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        guard let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) else { return nil }
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: 0, y: size.height),
                               end: CGPoint(x: 0, y: 0),
                               options: [])
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }

    // MARK: - Styled button (pill + label)
    static func makeButton(text: String, name: String, width: CGFloat = 280, height: CGFloat = 54) -> SKNode {
        let container = SKNode()
        container.name = name

        let pill = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height/2)
        pill.fillColor   = buttonBg
        pill.strokeColor = buttonBorder
        pill.lineWidth   = 2
        pill.name = name
        container.addChild(pill)

        let lbl = SKLabelNode(fontNamed: bodyFont)
        lbl.text = text
        lbl.fontSize = 22
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.name = name
        container.addChild(lbl)

        return container
    }

    // MARK: - Cat player node (emoji on coloured circle)
    static func makeCatNode(size: CGFloat = 40) -> SKNode {
        let node = SKNode()

        let circle = SKShapeNode(circleOfRadius: size * 0.55)
        circle.fillColor   = UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1)
        circle.strokeColor = UIColor(red: 1.0, green: 0.5, blue: 0, alpha: 1)
        circle.lineWidth   = 2
        circle.zPosition   = 0
        node.addChild(circle)

        let emoji = SKLabelNode(text: "🐱")
        emoji.fontSize = size * 0.9
        emoji.verticalAlignmentMode = .center
        emoji.horizontalAlignmentMode = .center
        emoji.zPosition = 1
        node.addChild(emoji)

        return node
    }

    // MARK: - Car node (emoji on coloured rounded rect)
    static func makeCarNode(behavior: CarBehavior, size: CGSize) -> SKNode {
        let node = SKNode()

        let body = SKShapeNode(rectOf: size, cornerRadius: 8)
        body.fillColor   = behavior.color
        body.strokeColor = behavior.color.withAlphaComponent(0.4)
        body.lineWidth   = 1
        body.zPosition   = 0
        node.addChild(body)

        // windshield stripe
        let windH = size.height * 0.22
        let wind = SKShapeNode(rectOf: CGSize(width: size.width * 0.75, height: windH), cornerRadius: 3)
        wind.fillColor   = UIColor(white: 1, alpha: 0.35)
        wind.strokeColor = .clear
        wind.position    = CGPoint(x: 0, y: size.height * 0.2)
        wind.zPosition   = 1
        node.addChild(wind)

        // headlights
        for xSide: CGFloat in [-1, 1] {
            let light = SKShapeNode(circleOfRadius: 4)
            light.fillColor   = UIColor(red: 1, green: 1, blue: 0.6, alpha: 0.9)
            light.strokeColor = .clear
            light.position    = CGPoint(x: xSide * (size.width * 0.3), y: -(size.height * 0.42))
            light.zPosition   = 1
            node.addChild(light)
        }

        // car emoji label
        let emoji = SKLabelNode(text: carEmoji(for: behavior))
        emoji.fontSize = min(size.width, size.height) * 0.55
        emoji.verticalAlignmentMode = .center
        emoji.horizontalAlignmentMode = .center
        emoji.zPosition = 2
        node.addChild(emoji)

        return node
    }

    private static func carEmoji(for behavior: CarBehavior) -> String {
        switch behavior {
        case .aggressive, .reckless: return "🚗"
        case .cautious, .polite:     return "🚙"
        case .impatient, .tailgater: return "🏎️"
        case .distracted:            return "🚕"
        case .lazy, .rubberneck:     return "🚌"
        }
    }

    // MARK: - HUD panel
    static func makeHUDPanel(size: CGSize) -> SKShapeNode {
        let panel = SKShapeNode(rectOf: size, cornerRadius: 10)
        panel.fillColor   = hudBg
        panel.strokeColor = UIColor(white: 1, alpha: 0.1)
        panel.lineWidth   = 1
        return panel
    }

    // MARK: - Stars / decorative dots
    static func addStarfield(to scene: SKScene, count: Int = 60) {
        for _ in 0..<count {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2.5))
            dot.fillColor   = UIColor(white: 1, alpha: CGFloat.random(in: 0.3...0.9))
            dot.strokeColor = .clear
            dot.position    = CGPoint(x: CGFloat.random(in: 0...scene.size.width),
                                      y: CGFloat.random(in: 0...scene.size.height))
            dot.zPosition   = -90
            scene.addChild(dot)
        }
    }

    // MARK: - Paw print decoration
    static func addPawPrints(to scene: SKScene) {
        let positions: [CGPoint] = [
            CGPoint(x: scene.size.width * 0.15, y: scene.size.height * 0.15),
            CGPoint(x: scene.size.width * 0.85, y: scene.size.height * 0.12),
            CGPoint(x: scene.size.width * 0.1,  y: scene.size.height * 0.85),
            CGPoint(x: scene.size.width * 0.88, y: scene.size.height * 0.8),
        ]
        for pt in positions {
            let paw = SKLabelNode(text: "🐾")
            paw.fontSize  = 28
            paw.alpha     = 0.18
            paw.position  = pt
            paw.zPosition = -80
            scene.addChild(paw)
        }
    }
}
