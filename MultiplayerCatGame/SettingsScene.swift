import SpriteKit

class SettingsScene: SKScene {
    private var controlOption = UserDefaults.standard.string(forKey: "controlOption") ?? "Touch"
    private var controlLabel: SKLabelNode!

    override func didMove(to view: SKView) {
        VisualFactory.addGradientBackground(
            to: self,
            topColor: UIColor(red: 0.08, green: 0.04, blue: 0.18, alpha: 1),
            bottomColor: UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1)
        )
        VisualFactory.addStarfield(to: self, count: 40)
        VisualFactory.addPawPrints(to: self)

        // Title
        let title = SKLabelNode(fontNamed: VisualFactory.titleFont)
        title.text = "⚙️  Settings"
        title.fontSize = 32
        title.fontColor = .white
        title.position = CGPoint(x: frame.midX, y: frame.height * 0.78)
        title.zPosition = 2
        addChild(title)

        // Section header
        let header = SKLabelNode(fontNamed: VisualFactory.bodyFont)
        header.text = "Controls"
        header.fontSize = 18
        header.fontColor = VisualFactory.accentOrange
        header.position = CGPoint(x: frame.midX, y: frame.height * 0.62)
        header.zPosition = 2
        addChild(header)

        // Control value label
        controlLabel = SKLabelNode(fontNamed: VisualFactory.labelFont)
        controlLabel.text = controlEmoji(controlOption)
        controlLabel.fontSize = 22
        controlLabel.fontColor = .white
        controlLabel.position = CGPoint(x: frame.midX, y: frame.height * 0.54)
        controlLabel.zPosition = 2
        addChild(controlLabel)

        // Toggle button
        let toggleBtn = VisualFactory.makeButton(text: "Toggle Control", name: "toggle")
        toggleBtn.position = CGPoint(x: frame.midX, y: frame.height * 0.44)
        toggleBtn.zPosition = 2
        addChild(toggleBtn)

        // Divider
        let divPath = CGMutablePath()
        divPath.move(to: CGPoint(x: frame.midX - 120, y: frame.height * 0.35))
        divPath.addLine(to: CGPoint(x: frame.midX + 120, y: frame.height * 0.35))
        let div = SKShapeNode(path: divPath)
        div.strokeColor = UIColor(white: 1, alpha: 0.12)
        div.zPosition = 2
        addChild(div)

        // Back button
        let backBtn = VisualFactory.makeButton(text: "← Back to Menu", name: "back", width: 240, height: 48)
        backBtn.position = CGPoint(x: frame.midX, y: frame.height * 0.25)
        backBtn.zPosition = 2
        addChild(backBtn)
    }

    private func controlEmoji(_ option: String) -> String {
        option == "Touch" ? "👆 Touch" : "📱 Accelerometer"
    }

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let node = nodes(at: touches.first!.location(in: self)).first else { return }
        switch node.name {
        case "toggle":
            controlOption = (controlOption == "Touch") ? "Accelerometer" : "Touch"
            controlLabel.text = controlEmoji(controlOption)
            UserDefaults.standard.set(controlOption, forKey: "controlOption")
            // Bounce feedback
            controlLabel.run(.sequence([.scale(to: 1.3, duration: 0.1), .scale(to: 1.0, duration: 0.1)]))
        case "back":
            let menu = MenuScene(size: size)
            menu.scaleMode = .resizeFill
            view?.presentScene(menu, transition: .push(with: .right, duration: 0.4))
        default:
            break
        }
    }
}
