// MenuScene.swift
import SpriteKit

class MenuScene: SKScene {

    // MARK: - Background animation state
    private let behaviors: [CarBehavior] = [.aggressive, .cautious, .reckless, .polite, .impatient, .lazy]
    private var spawnTimer: TimeInterval = 0

    // MARK: - Setup
    override func didMove(to view: SKView) {
        VisualFactory.addGradientBackground(
            to: self,
            topColor: UIColor(red: 0.08, green: 0.04, blue: 0.18, alpha: 1),
            bottomColor: UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1)
        )
        VisualFactory.addStarfield(to: self)
        VisualFactory.addPawPrints(to: self)
        setupAnimatedVisuals()

        // Title group — shadow + label share ONE parent, so both animate together (no static duplicate)
        let titleGroup = SKNode()
        titleGroup.position = CGPoint(x: frame.midX, y: frame.height * 0.76)
        titleGroup.zPosition = 10
        addChild(titleGroup)

        let titleShadow = SKLabelNode(fontNamed: VisualFactory.titleFont)
        titleShadow.text = "🐱 Cat vs Traffic 🚗"
        titleShadow.fontSize = 34
        titleShadow.fontColor = UIColor(red: 0.55, green: 0.2, blue: 0.9, alpha: 0.6)
        titleShadow.position = CGPoint(x: 3, y: -3)
        titleGroup.addChild(titleShadow)

        let titleLabel = SKLabelNode(fontNamed: VisualFactory.titleFont)
        titleLabel.text = "🐱 Cat vs Traffic 🚗"
        titleLabel.fontSize = 34
        titleLabel.fontColor = .white
        titleGroup.addChild(titleLabel)

        let pulse = SKAction.sequence([.scale(to: 1.06, duration: 0.9), .scale(to: 1.0, duration: 0.9)])
        let float = SKAction.sequence([.moveBy(x: 0, y: 6, duration: 1.1), .moveBy(x: 0, y: -6, duration: 1.1)])
        titleGroup.run(.repeatForever(pulse))
        titleGroup.run(.repeatForever(float))

        // Subtitle — fades in
        let sub = SKLabelNode(fontNamed: VisualFactory.labelFont)
        sub.text = "Dodge the traffic. Survive."
        sub.fontSize = 17
        sub.fontColor = UIColor(white: 0.7, alpha: 1)
        sub.position = CGPoint(x: frame.midX, y: frame.height * 0.69)
        sub.zPosition = 10
        sub.alpha = 0
        addChild(sub)
        sub.run(.sequence([.wait(forDuration: 0.4), .fadeIn(withDuration: 0.8)]))

        // Buttons — staggered fade-in
        let buttons: [(String, String)] = [
            ("🎮  Single Player", "single"),
            ("👥  Multiplayer",   "multi"),
            ("⚙️  Settings",      "settings")
        ]
        for (i, (text, name)) in buttons.enumerated() {
            let btn = VisualFactory.makeButton(text: text, name: name)
            btn.position = CGPoint(x: frame.midX, y: frame.height * (0.56 - CGFloat(i) * 0.12))
            btn.zPosition = 10
            btn.alpha = 0
            addChild(btn)
            btn.run(.sequence([.wait(forDuration: 0.6 + Double(i) * 0.15), .fadeIn(withDuration: 0.5)]))
        }

        let ver = SKLabelNode(fontNamed: VisualFactory.labelFont)
        ver.text = "v1.0"
        ver.fontSize = 13
        ver.fontColor = UIColor(white: 0.35, alpha: 1)
        ver.position = CGPoint(x: frame.midX, y: 20)
        ver.zPosition = 10
        addChild(ver)
    }

    // MARK: - Animated background visuals
    private func setupAnimatedVisuals() {
        for _ in 0..<5 { spawnBackgroundCar(startOnScreen: true) }
        for _ in 0..<3 { spawnBackgroundCat() }
    }

    override func update(_ currentTime: TimeInterval) {
        if spawnTimer == 0 { spawnTimer = currentTime }
        if currentTime - spawnTimer > 2.2 {
            spawnTimer = currentTime
            spawnBackgroundCar(startOnScreen: false)
            if Bool.random() { spawnBackgroundCat() }
        }
        children.filter { $0.name == "bgCar" || $0.name == "bgCat" }.forEach { node in
            if node.position.y < -120 { node.removeFromParent() }
        }
    }

    private func spawnBackgroundCar(startOnScreen: Bool) {
        let behavior = behaviors.randomElement()!
        let carSize = CGSize(width: 44, height: 64)
        let carNode = VisualFactory.makeCarNode(behavior: behavior, size: carSize)
        carNode.name = "bgCar"
        carNode.zPosition = 3
        carNode.alpha = 0.28

        let startY: CGFloat = startOnScreen
            ? CGFloat.random(in: 100...(frame.height - 50))
            : frame.height + 80
        carNode.position = CGPoint(x: CGFloat.random(in: 20...(frame.width - 20)), y: startY)

        let wobble = SKAction.sequence([.moveBy(x: 5, y: 0, duration: 0.7), .moveBy(x: -5, y: 0, duration: 0.7)])
        let speed = CGFloat.random(in: 60...130)
        let travelTime = Double((startY + 120) / speed)
        carNode.run(.group([.repeatForever(wobble), .moveBy(x: 0, y: -(startY + 120), duration: travelTime)]))
        addChild(carNode)
    }

    private func spawnBackgroundCat() {
        let catNode = VisualFactory.makeCatNode(size: 28)
        catNode.name = "bgCat"
        catNode.zPosition = 4
        catNode.alpha = 0.22

        let startX: CGFloat = Bool.random()
            ? CGFloat.random(in: -10...40)
            : CGFloat.random(in: (frame.width - 40)...(frame.width + 10))
        catNode.position = CGPoint(x: startX, y: CGFloat.random(in: 80...(frame.height - 80)))

        let targetX: CGFloat = startX < frame.midX ? frame.width + 60 : -60
        let hop = SKAction.sequence([.moveBy(x: 0, y: 12, duration: 0.25), .moveBy(x: 0, y: -12, duration: 0.25)])
        catNode.run(.group([
            .repeatForever(hop),
            .sequence([.moveTo(x: targetX, duration: Double.random(in: 4...8)), .removeFromParent()])
        ]))
        addChild(catNode)
    }

    // MARK: - Input
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let loc = touches.first?.location(in: self),
              let name = nodes(at: loc).first?.name else { return }
        switch name {
        case "single":
            let game = GameScene(size: size)
            game.isMultiplayer = false
            game.scaleMode = .resizeFill
            view?.presentScene(game, transition: .doorway(withDuration: 0.5))
        case "multi":
            let game = GameScene(size: size)
            game.isMultiplayer = true
            game.isHost = true
            game.scaleMode = .resizeFill
            view?.presentScene(game, transition: .doorway(withDuration: 0.5))
        case "settings":
            let settings = SettingsScene(size: size)
            settings.scaleMode = .resizeFill
            view?.presentScene(settings, transition: .push(with: .left, duration: 0.4))
        default:
            break
        }
    }
}
