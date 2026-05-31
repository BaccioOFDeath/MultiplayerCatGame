// LobbyScene.swift
import SpriteKit
import MultipeerConnectivity

class LobbyScene: SKScene, MCManagerDelegate {
    let mc = MCManager.shared
    private var peers: [MCPeerID] = []
    private var isHost = false
    private var statusLabel: SKLabelNode!

    override func didMove(to view: SKView) {
        VisualFactory.addGradientBackground(
            to: self,
            topColor: UIColor(red: 0.05, green: 0.1, blue: 0.22, alpha: 1),
            bottomColor: UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1)
        )
        VisualFactory.addStarfield(to: self, count: 40)
        VisualFactory.addPawPrints(to: self)
        mc.delegate = self

        // Title
        let title = SKLabelNode(fontNamed: VisualFactory.titleFont)
        title.text = "👥  Multiplayer Lobby"
        title.fontSize = 28
        title.fontColor = .white
        title.position = CGPoint(x: frame.midX, y: frame.height * 0.88)
        title.zPosition = 2
        addChild(title)

        // Status label
        statusLabel = SKLabelNode(fontNamed: VisualFactory.labelFont)
        statusLabel.text = "Choose Host or Join"
        statusLabel.fontSize = 17
        statusLabel.fontColor = VisualFactory.accentOrange
        statusLabel.position = CGPoint(x: frame.midX, y: frame.height * 0.79)
        statusLabel.zPosition = 2
        addChild(statusLabel)

        // Buttons
        let hostBtn  = VisualFactory.makeButton(text: "📡  Host Game",   name: "host")
        let joinBtn  = VisualFactory.makeButton(text: "🔍  Join Game",   name: "join")
        let startBtn = VisualFactory.makeButton(text: "▶️  Start Game",  name: "start", width: 240, height: 50)
        let backBtn  = VisualFactory.makeButton(text: "← Back",         name: "back",  width: 180, height: 44)

        hostBtn.position  = CGPoint(x: frame.midX, y: frame.height * 0.68)
        joinBtn.position  = CGPoint(x: frame.midX, y: frame.height * 0.56)
        startBtn.position = CGPoint(x: frame.midX, y: frame.height * 0.20)
        backBtn.position  = CGPoint(x: frame.midX, y: frame.height * 0.09)

        for btn in [hostBtn, joinBtn, startBtn, backBtn] {
            btn.zPosition = 2
            addChild(btn)
        }

        redrawPeerList()
    }

    private func redrawPeerList() {
        children.filter { $0.name?.starts(with: "peer_") == true }.forEach { $0.removeFromParent() }

        let headerY = frame.height * 0.45
        let header = SKLabelNode(fontNamed: VisualFactory.bodyFont)
        header.text = peers.isEmpty ? "No players connected yet…" : "Connected Players:"
        header.fontSize = 16
        header.fontColor = UIColor(white: 0.6, alpha: 1)
        header.position = CGPoint(x: frame.midX, y: headerY)
        header.name = "peer_header"
        header.zPosition = 2
        addChild(header)

        for (i, peer) in peers.enumerated() {
            let row = SKNode()
            row.name = "peer_\(i)"
            row.zPosition = 2

            let pill = SKShapeNode(rectOf: CGSize(width: 260, height: 36), cornerRadius: 18)
            pill.fillColor   = UIColor(red: 0.15, green: 0.6, blue: 0.35, alpha: 0.5)
            pill.strokeColor = UIColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 0.7)
            pill.lineWidth   = 1
            row.addChild(pill)

            let dot = SKLabelNode(text: "🟢")
            dot.fontSize = 13
            dot.horizontalAlignmentMode = .left
            dot.verticalAlignmentMode = .center
            dot.position = CGPoint(x: -115, y: 0)
            row.addChild(dot)

            let lbl = SKLabelNode(fontNamed: VisualFactory.labelFont)
            lbl.text = peer.displayName
            lbl.fontSize = 17
            lbl.fontColor = .white
            lbl.verticalAlignmentMode = .center
            row.addChild(lbl)

            row.position = CGPoint(x: frame.midX, y: headerY - CGFloat(i + 1) * 44)
            addChild(row)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let name = nodes(at: touches.first!.location(in: self)).first?.name else { return }
        switch name {
        case "host":
            isHost = true
            mc.startHostingAndBrowsing()
            statusLabel.text = "📡 Hosting — waiting for players…"
        case "join":
            isHost = false
            mc.startHostingAndBrowsing()
            statusLabel.text = "🔍 Searching for a game…"
        case "start":
            let game = GameScene(size: size)
            game.isMultiplayer = true
            game.isHost = isHost
            game.scaleMode = .resizeFill
            view?.presentScene(game, transition: .doorway(withDuration: 0.5))
        case "back":
            let menu = MenuScene(size: size)
            menu.scaleMode = .resizeFill
            view?.presentScene(menu, transition: .push(with: .right, duration: 0.4))
        default:
            break
        }
    }

    // MARK: - MCManagerDelegate
    func connectedPeersChanged(_ peers: [MCPeerID]) {
        self.peers = peers
        redrawPeerList()
        statusLabel.text = peers.isEmpty ? "Searching…" : "\(peers.count) player(s) connected ✓"
    }

    func receivedData(_ data: Data, from peer: MCPeerID) {}
}
