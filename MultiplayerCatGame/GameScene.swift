// GameScene.swift
import UIKit
import SpriteKit
import CoreMotion
import MultipeerConnectivity

class GameScene: SKScene, MCManagerDelegate {
    var isMultiplayer = false
    var isHost = false
    var controlOption = "Touch"

    let mc = MCManager.shared
    private var player = SKSpriteNode()
    private var scoreLabel  = SKLabelNode()
    private var livesLabel  = SKLabelNode()
    private var peersLabel  = SKLabelNode()
    private let motionManager = CMMotionManager()

    private var score = 0
    private var lives = 9
    private var isInvincible = false
    private let hitCooldown: TimeInterval = 1.0

    private var lastUpdate: TimeInterval = 0
    private var lastHit: TimeInterval = 0
    private var lastTrafficSend: TimeInterval = 0
    private let trafficInterval: TimeInterval = 1.0 / 10.0

    private var roadWidth: CGFloat { size.width * 0.8 }
    private let carSize  = CGSize(width: 70, height: 100)
    private let catSize  = CGSize(width: 40, height: 40)

    private lazy var opponentManager = OpponentManager(roadRatio: 0.8, carSize: carSize)
    private var remotePlayers = [MCPeerID: SKSpriteNode]()

    private let legendBehaviors: [CarBehavior] = [
        .cautious, .polite, .aggressive,
        .impatient, .distracted, .reckless,
        .lazy, .tailgater, .rubberneck
    ]

    private let trafficCount = 6
    private var authorityPeer: MCPeerID?
    private var lastReceivedTrafficPositions = [[String: Double]]()

    // Speed lines container
    private var speedLinesNode = SKNode()
    private var lastSpeedLineTime: TimeInterval = 0

    // MARK: - Authority
    private func updateAuthorityPeer() {
        let allPeers = mc.session.connectedPeers + [mc.peerID]
        authorityPeer = allPeers.sorted { $0.displayName < $1.displayName }.first
    }

    private func updateOpponentPositions(_ positions: [[String: Double]]) {
        for (i, p) in positions.enumerated() {
            guard i < opponentManager.opponents.count else { break }
            let car = opponentManager.opponents[i]
            let target = CGPoint(x: CGFloat(p["xPct"]!) * size.width,
                                 y: CGFloat(p["yPct"]!) * size.height)
            car.position = car.position.lerp(to: target, t: 0.25)
        }
    }

    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        self.size = view.bounds.size
        self.scaleMode = .resizeFill

        setupBackground()
        setupRoad()
        setupSpeedLines()
        setupPlayer()
        setupHUD()
        setupLegend()

        score = 0; lives = 9; lastHit = 0; lastUpdate = 0; lastTrafficSend = 0
        updateHUD()

        controlOption = UserDefaults.standard.string(forKey: "controlOption") ?? "Touch"
        if controlOption == "Accelerometer" { setupMotion() }

        if isMultiplayer {
            mc.delegate = self
            mc.startHostingAndBrowsing()
            updateAuthorityPeer()
            if authorityPeer == mc.peerID {
                let positions = opponentManager.spawn(count: trafficCount, in: self)
                mc.broadcastTraffic(positions)
            }
        } else {
            opponentManager.spawn(count: trafficCount, in: self)
        }
    }

    private func resetGame() {
        score = 0; lives = 9; lastHit = 0; isPaused = false
        enumerateChildNodes(withName: "//gameOverGroup") { node, _ in node.removeFromParent() }
        player.position = CGPoint(x: size.width/2, y: size.height/2)
        player.alpha = 1
        updateHUD()
        if isMultiplayer {
            updateAuthorityPeer()
            if authorityPeer == mc.peerID {
                let positions = opponentManager.spawn(count: trafficCount, in: self)
                mc.broadcastTraffic(positions)
            }
        } else {
            opponentManager.spawn(count: trafficCount, in: self)
        }
    }

    // MARK: - Update
    override func update(_ currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime; return }
        let dt = currentTime - lastUpdate
        lastUpdate = currentTime

        animateSpeedLines(currentTime)

        if isMultiplayer && authorityPeer != mc.peerID {
            updateOpponentPositions(lastReceivedTrafficPositions)
            checkCollisions(currentTime: currentTime)
            score += Int(dt * 60); updateHUD()
            return
        }

        opponentManager.update(in: self, player: player, currentTime: currentTime)
        if isMultiplayer && authorityPeer == mc.peerID && currentTime - lastTrafficSend >= trafficInterval {
            lastTrafficSend = currentTime
            let positions = opponentManager.currentPositions(in: self)
            mc.broadcastTraffic(positions)
        }

        checkCollisions(currentTime: currentTime)
        score += Int(dt * 60); updateHUD()
    }

    // MARK: - Background
    private func setupBackground() {
        VisualFactory.addGradientBackground(
            to: self,
            topColor: UIColor(red: 0.08, green: 0.13, blue: 0.08, alpha: 1),
            bottomColor: UIColor(red: 0.03, green: 0.05, blue: 0.03, alpha: 1)
        )
    }

    // MARK: - Road
    private func setupRoad() {
        let rw = roadWidth
        // Grass shoulders
        for (x, w): (CGFloat, CGFloat) in [
            (0, (size.width - rw)/2),
            ((size.width + rw)/2, (size.width - rw)/2)
        ] {
            let grass = SKShapeNode(rect: CGRect(x: x, y: 0, width: w, height: size.height))
            grass.fillColor = UIColor(red: 0.1, green: 0.2, blue: 0.1, alpha: 1)
            grass.strokeColor = .clear; grass.zPosition = -51; addChild(grass)
            // grass texture dots
            for _ in 0..<12 {
                let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
                dot.fillColor = UIColor(red: 0.15, green: 0.28, blue: 0.13, alpha: 0.7)
                dot.strokeColor = .clear
                dot.position = CGPoint(x: CGFloat.random(in: x...(x+w)), y: CGFloat.random(in: 0...size.height))
                dot.zPosition = -50; addChild(dot)
            }
        }

        // Road surface
        let road = SKShapeNode(rect: CGRect(x: (size.width - rw)/2, y: 0, width: rw, height: size.height))
        road.fillColor = UIColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1)
        road.strokeColor = .clear; road.zPosition = -49; addChild(road)

        // Road subtle texture — random light specks
        for _ in 0..<40 {
            let speck = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2))
            speck.fillColor = UIColor(white: 0.3, alpha: CGFloat.random(in: 0.1...0.3))
            speck.strokeColor = .clear
            speck.position = CGPoint(
                x: CGFloat.random(in: (size.width - rw)/2...(size.width + rw)/2),
                y: CGFloat.random(in: 0...size.height)
            )
            speck.zPosition = -48; addChild(speck)
        }

        // White curb edge lines
        for xEdge in [(size.width - rw)/2, (size.width + rw)/2] {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: xEdge, y: 0))
            p.addLine(to: CGPoint(x: xEdge, y: size.height))
            let edge = SKShapeNode(path: p)
            edge.strokeColor = UIColor(white: 0.85, alpha: 0.9)
            edge.lineWidth = 4; edge.zPosition = -47; addChild(edge)
        }

        // Animated scrolling center dashes
        let dashContainer = SKNode()
        dashContainer.name = "dashContainer"; dashContainer.zPosition = -46; addChild(dashContainer)
        let dash: CGFloat = 44, gap: CGFloat = 22
        var y: CGFloat = 0
        while y < size.height + dash + gap {
            let seg = SKShapeNode(rect: CGRect(x: size.width/2 - 3, y: y, width: 6, height: dash))
            seg.fillColor = UIColor(white: 0.75, alpha: 0.7); seg.strokeColor = .clear
            dashContainer.addChild(seg); y += dash + gap
        }
        dashContainer.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: -(dash + gap), duration: 0.45),
            .moveBy(x: 0, y:  (dash + gap), duration: 0)
        ])))
    }

    // MARK: - Speed lines
    private func setupSpeedLines() {
        speedLinesNode.zPosition = -10
        addChild(speedLinesNode)
    }

    private func animateSpeedLines(_ currentTime: TimeInterval) {
        guard currentTime - lastSpeedLineTime > 0.08 else { return }
        lastSpeedLineTime = currentTime

        speedLinesNode.children.forEach { node in
            if node.position.y < -20 { node.removeFromParent() }
        }

        let rw = roadWidth
        let x = CGFloat.random(in: (size.width - rw)/2...(size.width + rw)/2)
        let lineH = CGFloat.random(in: 30...90)
        let line = SKShapeNode(rect: CGRect(x: x, y: size.height + 10, width: 2, height: lineH))
        line.fillColor = UIColor(white: 1, alpha: CGFloat.random(in: 0.04...0.12))
        line.strokeColor = .clear
        speedLinesNode.addChild(line)
        line.run(.sequence([
            .moveBy(x: 0, y: -(size.height + lineH + 30), duration: 0.6),
            .removeFromParent()
        ]))
    }

    // MARK: - Player
    private func setupPlayer() {
        player = SKSpriteNode(color: .clear, size: catSize)
        player.position = CGPoint(x: size.width/2, y: size.height/2)
        player.zPosition = 20
        let catVisual = VisualFactory.makeCatNode(size: catSize.width)
        catVisual.name = "catVisual"
        player.addChild(catVisual)
        addChild(player)

        // Idle bobbing animation
        catVisual.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 3, duration: 0.4),
            .moveBy(x: 0, y: -3, duration: 0.4)
        ])))
    }

    // MARK: - HUD
    private func setupHUD() {
        // Top bar background
        let barH: CGFloat = 54
        let bar = SKShapeNode(rect: CGRect(x: 0, y: size.height - barH, width: size.width, height: barH))
        bar.fillColor = UIColor(white: 0, alpha: 0.55)
        bar.strokeColor = UIColor(white: 1, alpha: 0.08)
        bar.zPosition = 30
        bar.name = "hudBar"
        addChild(bar)

        // Score pill
        let scorePill = VisualFactory.makeHUDPanel(size: CGSize(width: 120, height: 36))
        scorePill.position = CGPoint(x: 68, y: size.height - 27)
        scorePill.zPosition = 31; addChild(scorePill)

        scoreLabel = SKLabelNode(fontNamed: VisualFactory.bodyFont)
        scoreLabel.fontSize = 18; scoreLabel.fontColor = .white
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: 68, y: size.height - 27)
        scoreLabel.zPosition = 32; addChild(scoreLabel)

        // Lives pill
        let livesPill = VisualFactory.makeHUDPanel(size: CGSize(width: 140, height: 36))
        livesPill.position = CGPoint(x: size.width - 78, y: size.height - 27)
        livesPill.zPosition = 31; addChild(livesPill)

        livesLabel = SKLabelNode(fontNamed: VisualFactory.bodyFont)
        livesLabel.fontSize = 18
        livesLabel.fontColor = UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)
        livesLabel.verticalAlignmentMode = .center
        livesLabel.position = CGPoint(x: size.width - 78, y: size.height - 27)
        livesLabel.zPosition = 32; addChild(livesLabel)

        // Peers label
        peersLabel = SKLabelNode(fontNamed: VisualFactory.labelFont)
        peersLabel.fontSize = 13; peersLabel.fontColor = VisualFactory.accentOrange
        peersLabel.verticalAlignmentMode = .center
        peersLabel.position = CGPoint(x: size.width/2, y: size.height - 27)
        peersLabel.zPosition = 32; addChild(peersLabel)
    }

    private func updateHUD() {
        scoreLabel.text = "🏅 \(score)"
        livesLabel.text = lives > 0 ? String(repeating: "❤️", count: min(lives, 9)) : "💀"
        let names = mc.session.connectedPeers.map(\.displayName)
        peersLabel.text = names.isEmpty ? "" : "👥 " + names.joined(separator: ", ")
    }

    // MARK: - Legend
    private func setupLegend() {
        let margin: CGFloat = 14
        let sw = CGSize(width: 16, height: 16)
        let startX = margin + sw.width/2
        let startY = size.height - 70

        for (i, behavior) in legendBehaviors.enumerated() {
            let y = startY - CGFloat(i) * (sw.height + 6)

            let swatch = SKShapeNode(rectOf: sw, cornerRadius: 4)
            swatch.fillColor   = behavior.color
            swatch.strokeColor = UIColor(white: 1, alpha: 0.2)
            swatch.lineWidth   = 1
            swatch.position    = CGPoint(x: startX, y: y)
            swatch.zPosition   = 31; addChild(swatch)

            let lbl = SKLabelNode(fontNamed: VisualFactory.labelFont)
            lbl.text = {
                switch behavior {
                case .cautious: return "Cautious"; case .polite: return "Polite"
                case .aggressive: return "Aggressive"; case .impatient: return "Impatient"
                case .distracted: return "Distracted"; case .reckless: return "Reckless"
                case .lazy: return "Lazy"; case .tailgater: return "Tailgater"
                case .rubberneck: return "Rubberneck"
                }
            }()
            lbl.fontSize = 11; lbl.fontColor = UIColor(white: 0.82, alpha: 1)
            lbl.horizontalAlignmentMode = .left; lbl.verticalAlignmentMode = .center
            lbl.position = CGPoint(x: startX + sw.width/2 + 5, y: y)
            lbl.zPosition = 31; addChild(lbl)
        }
    }

    // MARK: - Motion
    private func setupMotion() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self,
                  let attitude = motion?.attitude,
                  let orientation = self.view?.window?.windowScene?.interfaceOrientation else { return }
            let sensitivity: CGFloat = 200
            var dx: CGFloat = 0, dy: CGFloat = 0
            switch orientation {
            case .portrait:            dx =  CGFloat(attitude.roll)  * sensitivity; dy = CGFloat(-attitude.pitch) * sensitivity
            case .portraitUpsideDown:  dx = -CGFloat(attitude.roll)  * sensitivity; dy = CGFloat( attitude.pitch) * sensitivity
            case .landscapeLeft:       dx = -CGFloat(attitude.pitch) * sensitivity; dy = CGFloat(-attitude.roll)  * sensitivity
            case .landscapeRight:      dx =  CGFloat(attitude.pitch) * sensitivity; dy = CGFloat( attitude.roll)  * sensitivity
            default:                   dx =  CGFloat(attitude.roll)  * sensitivity; dy = CGFloat(-attitude.pitch) * sensitivity
            }
            self.player.position.x = self.clamp(self.player.position.x + dx, 0, self.size.width)
            self.player.position.y = self.clamp(self.player.position.y + dy, 0, self.size.height)
            self.sendPosition()
        }
    }

    // MARK: - Touch
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard controlOption == "Touch", let t = touches.first else { return }
        let loc = t.location(in: self), prev = t.previousLocation(in: self)
        player.position.x = clamp(player.position.x + loc.x - prev.x, 0, size.width)
        player.position.y = clamp(player.position.y + loc.y - prev.y, 0, size.height)
        sendPosition()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let loc = touches.first?.location(in: self) else { return }
        for node in nodes(at: loc) {
            switch node.name {
            case "retry": resetGame()
            case "menu":
                let m = MenuScene(size: size); m.scaleMode = scaleMode
                view?.presentScene(m, transition: .doorway(withDuration: 0.5))
            default: break
            }
        }
    }

    // MARK: - Collisions
    private func checkCollisions(currentTime: TimeInterval) {
        for car in opponentManager.opponents where player.frame.intersects(car.frame) {
            guard currentTime - lastHit > hitCooldown else { return }
            lives -= 1
            lastHit = currentTime
            isInvincible = true
            blinkPlayer()
            flashScreen()
            shakeCamera()
            mc.sendHit()
            if lives <= 0 { gameOver() }
            return
        }
        if currentTime - lastHit > hitCooldown { isInvincible = false }
    }

    // Player blink on hit
    private func blinkPlayer() {
        let d = hitCooldown / 10
        let seq = SKAction.sequence([.fadeAlpha(to: 0.1, duration: d), .fadeAlpha(to: 1, duration: d)])
        player.run(.repeat(seq, count: Int(hitCooldown / (d * 2))))
    }

    // Red screen flash
    private func flashScreen() {
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor   = UIColor(red: 1, green: 0.1, blue: 0.1, alpha: 0.35)
        flash.strokeColor = .clear
        flash.zPosition   = 90
        addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.05),
            .fadeAlpha(to: 0,    duration: 0.25),
            .removeFromParent()
        ]))
    }

    // Camera shake
    private func shakeCamera() {
        let shakeAmt: CGFloat = 8
        let duration = 0.06
        let seq = SKAction.sequence([
            .moveBy(x:  shakeAmt, y:  shakeAmt, duration: duration),
            .moveBy(x: -shakeAmt, y: -shakeAmt, duration: duration),
            .moveBy(x:  shakeAmt, y: -shakeAmt, duration: duration),
            .moveBy(x: -shakeAmt, y:  shakeAmt, duration: duration),
            .moveBy(x: 0,         y: 0,          duration: 0)
        ])
        // shake the road & cars container by moving children is costly; instead shake the view
        run(seq)
    }

    // Spark burst at cat position
    private func spawnHitSparks(at position: CGPoint) {
        for _ in 0..<10 {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            spark.fillColor   = [UIColor.orange, UIColor.yellow, UIColor.red].randomElement()!
            spark.strokeColor = .clear
            spark.position    = position
            spark.zPosition   = 50
            addChild(spark)
            let angle  = CGFloat.random(in: 0...(2 * .pi))
            let dist   = CGFloat.random(in: 20...60)
            spark.run(.sequence([
                .group([
                    .moveBy(x: cos(angle)*dist, y: sin(angle)*dist, duration: 0.35),
                    .fadeOut(withDuration: 0.35)
                ]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Game Over
    private func gameOver() {
        isPaused = true
        spawnHitSparks(at: player.position)

        let group = SKNode(); group.name = "gameOverGroup"; group.zPosition = 60; addChild(group)

        // Dim overlay
        let overlay = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        overlay.fillColor = UIColor(white: 0, alpha: 0.72); overlay.strokeColor = .clear
        group.addChild(overlay)

        // Panel
        let pw: CGFloat = min(size.width - 50, 320)
        let panel = SKShapeNode(rectOf: CGSize(width: pw, height: 260), cornerRadius: 22)
        panel.fillColor   = UIColor(red: 0.08, green: 0.04, blue: 0.18, alpha: 0.97)
        panel.strokeColor = VisualFactory.accentPurple; panel.lineWidth = 2
        panel.position    = CGPoint(x: size.width/2, y: size.height/2)
        group.addChild(panel)

        // Animated skull
        let skull = SKLabelNode(text: "💀")
        skull.fontSize = 48; skull.verticalAlignmentMode = .center
        skull.position = CGPoint(x: size.width/2, y: size.height/2 + 90)
        skull.run(.repeatForever(.sequence([.scale(to: 1.2, duration: 0.4), .scale(to: 1.0, duration: 0.4)])))
        group.addChild(skull)

        // "Game Over!" label
        let title = SKLabelNode(fontNamed: VisualFactory.titleFont)
        title.text = "Game Over!"; title.fontSize = 30
        title.fontColor = UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: size.width/2, y: size.height/2 + 30)
        group.addChild(title)

        // Score
        let scoreLbl = SKLabelNode(fontNamed: VisualFactory.bodyFont)
        scoreLbl.text = "Final Score:  \(score)"; scoreLbl.fontSize = 21; scoreLbl.fontColor = .white
        scoreLbl.verticalAlignmentMode = .center
        scoreLbl.position = CGPoint(x: size.width/2, y: size.height/2 - 8)
        group.addChild(scoreLbl)

        // Buttons
        let retryBtn = VisualFactory.makeButton(text: "🔄  Try Again", name: "retry", width: pw - 40, height: 50)
        retryBtn.position = CGPoint(x: size.width/2, y: size.height/2 - 56); group.addChild(retryBtn)

        let menuBtn = VisualFactory.makeButton(text: "🏠  Main Menu", name: "menu", width: pw - 40, height: 44)
        menuBtn.position = CGPoint(x: size.width/2, y: size.height/2 - 108); group.addChild(menuBtn)

        // Panel slide-in
        panel.position.y -= 40; panel.alpha = 0
        panel.run(.group([.fadeIn(withDuration: 0.25), .moveBy(x: 0, y: 40, duration: 0.3)]))
    }

    // MARK: - Helpers
    private func sendPosition() {
        mc.sendPosition(xPct: Double(player.position.x / size.width),
                        yPct: Double(player.position.y / size.height))
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        Swift.min(Swift.max(v, lo), hi)
    }

    // MARK: - MCManagerDelegate
    func receivedData(_ data: Data, from peer: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = obj["type"] as? String else { return }
            switch type {
            case "traffic":
                guard self.isMultiplayer else { return }
                if let positions = obj["positions"] as? [[String: Double]] {
                    if self.opponentManager.opponents.isEmpty {
                        self.opponentManager.spawn(at: positions, in: self)
                    }
                    self.lastReceivedTrafficPositions = positions
                }
            case "hit":
                if let sprite = self.remotePlayers[peer] {
                    let d = self.hitCooldown / 10
                    let seq = SKAction.sequence([.fadeAlpha(to: 0.1, duration: d), .fadeAlpha(to: 1, duration: d)])
                    sprite.run(.repeat(seq, count: Int(self.hitCooldown / (d * 2))))
                }
            case "position":
                if let xp = obj["xPct"] as? Double, let yp = obj["yPct"] as? Double,
                   let sprite = self.remotePlayers[peer] {
                    let target = CGPoint(x: CGFloat(xp) * self.size.width,
                                        y: CGFloat(yp) * self.size.height)
                    sprite.position = sprite.position.lerp(to: target, t: 0.2)
                }
            default: break
            }
        }
    }

    func connectedPeersChanged(_ peers: [MCPeerID]) {
        for peer in peers {
            if remotePlayers[peer] == nil {
                let sprite = SKSpriteNode(color: .clear, size: catSize)
                sprite.name = peer.displayName
                sprite.position = CGPoint(x: size.width/2, y: size.height/2)
                sprite.zPosition = 18
                let remoteVisual = VisualFactory.makeCatNode(size: catSize.width)
                remoteVisual.alpha = 0.75
                sprite.addChild(remoteVisual)
                addChild(sprite)
                remotePlayers[peer] = sprite
            }
        }
        let removed = Set(remotePlayers.keys).subtracting(peers)
        for peer in removed { remotePlayers[peer]?.removeFromParent(); remotePlayers.removeValue(forKey: peer) }
        if isMultiplayer {
            updateAuthorityPeer()
            if authorityPeer == mc.peerID {
                mc.broadcastTraffic(opponentManager.currentPositions(in: self))
            }
        }
    }
}
