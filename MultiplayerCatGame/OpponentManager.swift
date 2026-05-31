// OpponentManager.swift
import SpriteKit

class OpponentManager {
    private(set) var opponents = [SKSpriteNode]()
    private var targetSpeeds = [SKSpriteNode: CGFloat]()
    private var currentSpeeds = [SKSpriteNode: CGFloat]()
    private var behaviors = [SKSpriteNode: CarBehavior]()
    private var avoidance = [SKSpriteNode: AvoidanceInfo]()
    private var politeStopTimes = [SKSpriteNode: TimeInterval]()
    
    let roadRatio: CGFloat
    let carSize: CGSize
    
    let minSpeed: CGFloat = 5
    let maxSpeed: CGFloat = 15
    let detectionBase: CGFloat = 150
    let lateralSmoothingBase: CGFloat = 0.05
    let politeThreshold: TimeInterval = 5.0
    
    private var spawnOffset: CGFloat { carSize.height * 2 }
    var laneOffset: CGFloat { carSize.width + 20 }
    var laneWidth: CGFloat  { carSize.width * 0.9 }
    
    init(roadRatio: CGFloat, carSize: CGSize) {
        self.roadRatio = roadRatio
        self.carSize = carSize
    }
    
    private func roadWidth(in scene: SKScene) -> CGFloat {
        scene.size.width * roadRatio
    }
    
    private func dynamicRange(for speed: CGFloat) -> CGFloat {
        detectionBase * (speed / maxSpeed) + 50
    }
    
    private let behaviorOptions: [CarBehavior] = [
        .cautious, .polite, .aggressive,
        .impatient, .distracted, .reckless,
        .lazy, .tailgater, .rubberneck
    ]
    
    @discardableResult
    func spawn(count: Int, in scene: SKScene) -> [[String: Double]] {
        opponents.forEach { $0.removeFromParent() }
        opponents.removeAll()
        targetSpeeds.removeAll()
        currentSpeeds.removeAll()
        behaviors.removeAll()
        avoidance.removeAll()
        politeStopTimes.removeAll()

        var data = [[String: Double]]()
        let rw   = roadWidth(in: scene)
        let xMin = (scene.size.width - rw)/2 + carSize.width/2
        let xMax = (scene.size.width + rw)/2 - carSize.width/2
        let yMin = scene.size.height
        let yMax = scene.size.height + spawnOffset

        for _ in 0..<count {
            let behavior = behaviorOptions.randomElement()!
            let car = makeCar(behavior: behavior)
            let x = CGFloat.random(in: xMin...xMax)
            let y = CGFloat.random(in: yMin...yMax)
            car.position = CGPoint(x: x, y: y)
            scene.addChild(car)
            opponents.append(car)

            let speed = CGFloat.random(in: minSpeed...maxSpeed)
            targetSpeeds[car] = speed
            currentSpeeds[car] = speed
            behaviors[car]     = behavior

            data.append([
                "xPct":  Double(x / scene.size.width),
                "yPct":  Double(y / scene.size.height),
                "speed": Double(speed)
            ])
        }
        return data
    }

    func spawn(at positions: [[String: Double]], in scene: SKScene) {
        opponents.forEach { $0.removeFromParent() }
        opponents.removeAll()
        targetSpeeds.removeAll()
        currentSpeeds.removeAll()
        behaviors.removeAll()
        avoidance.removeAll()
        politeStopTimes.removeAll()

        for pos in positions {
            let behavior = behaviorOptions.randomElement()!
            let car = makeCar(behavior: behavior)
            car.position = CGPoint(
                x: CGFloat(pos["xPct"]!) * scene.size.width,
                y: CGFloat(pos["yPct"]!) * scene.size.height
            )
            scene.addChild(car)
            opponents.append(car)

            let speed = CGFloat(pos["speed"] ?? Double((minSpeed + maxSpeed) / 2))
            targetSpeeds[car] = speed
            currentSpeeds[car] = speed
            behaviors[car]     = behavior
        }
    }

    func currentPositions(in scene: SKScene) -> [[String: Double]] {
        opponents.map { car in [
            "xPct":  Double(car.position.x / scene.size.width),
            "yPct":  Double(car.position.y / scene.size.height),
            "speed": Double(targetSpeeds[car] ?? (minSpeed + maxSpeed) / 2)
        ]}
    }

    // MARK: - Car factory
    private func makeCar(behavior: CarBehavior) -> SKSpriteNode {
        let car = SKSpriteNode(color: .clear, size: carSize)
        car.zPosition = 5
        // Visual node
        let visual = VisualFactory.makeCarNode(behavior: behavior, size: carSize)
        visual.name = "carVisual"
        car.addChild(visual)
        // Subtle engine idle bob
        visual.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 1.5, duration: 0.3),
            .moveBy(x: 0, y: -1.5, duration: 0.3)
        ])))
        return car
    }

    // MARK: - Update
    func update(in scene: SKScene, player: SKSpriteNode, currentTime: TimeInterval) {
        let rw    = roadWidth(in: scene)
        let xMin  = (scene.size.width  - rw)/2 + carSize.width/2
        let xMax  = (scene.size.width  + rw)/2 - carSize.width/2
        let yMin  = scene.size.height
        let yMax  = scene.size.height + spawnOffset

        let lateralDetect = laneWidth * 1.5

        for car in opponents {
            guard let behavior = behaviors[car],
                  let target   = targetSpeeds[car] else { continue }

            let frontY  = car.position.y - carSize.height/2
            let catNose = player.position.y + player.size.height/2
            if behavior == .polite, politeStopTimes[car] != nil, frontY < catNose {
                politeStopTimes[car] = nil; avoidance[car] = nil
            }

            let dx   = player.position.x - car.position.x
            let dy   = player.position.y - car.position.y
            let dist = hypot(dx, dy)

            let detectY = dynamicRange(for: target)
            let detectX = lateralDetect
            var desired = target

            if dist < detectY && abs(dx) < detectX {
                switch behavior {
                case .cautious:
                    desired = target * 0.5

                case .polite:
                    if politeStopTimes[car] == nil { politeStopTimes[car] = currentTime }
                    let waited = currentTime - politeStopTimes[car]!
                    if waited < 1 {
                        desired = 0
                    } else if waited < behavior.politeThreshold {
                        for offset in [-laneOffset, laneOffset] {
                            let tx = car.position.x + offset
                            if tx >= xMin && tx <= xMax && isFree(x: tx, y: car.position.y, excluding: car) {
                                avoidance[car] = AvoidanceInfo(originalX: car.position.x, targetX: tx, otherCar: car, returning: false)
                                politeStopTimes[car] = nil; break
                            }
                        }
                        desired = 0
                    } else {
                        behaviors[car] = .aggressive
                        refreshCarVisual(car, behavior: .aggressive)
                        politeStopTimes[car] = nil; desired = target
                    }

                case .aggressive:
                    car.position.x += (dx / max(dist,1)) * behavior.steerFactor * carSize.width
                    desired = target

                case .impatient:
                    if Bool.random() { car.position.x += (dx / max(dist,1)) * behavior.steerFactor * carSize.width }
                    desired = min(target * 1.2, maxSpeed)

                case .distracted:
                    desired = target * CGFloat.random(in: 0.4...0.8)

                case .reckless:
                    desired = maxSpeed

                case .lazy:
                    desired = target * 0.6

                case .tailgater:
                    desired = min(target * 1.3, maxSpeed)

                case .rubberneck:
                    desired = target * 0.2
                }
            } else {
                politeStopTimes[car] = nil
            }

            let previous   = currentSpeeds[car] ?? desired
            let smoothFact = 0.2 + (abs(desired)/maxSpeed)*0.2
            let speed      = previous + (desired - previous)*smoothFact
            currentSpeeds[car] = speed
            car.position.y -= speed

            // Respawn
            if car.position.y < -car.size.height {
                car.position = CGPoint(
                    x: CGFloat.random(in: xMin...xMax),
                    y: CGFloat.random(in: yMin...yMax)
                )
                let newSpeed      = CGFloat.random(in: minSpeed...maxSpeed)
                let newBehavior   = behaviorOptions.randomElement()!
                targetSpeeds[car] = newSpeed
                currentSpeeds[car] = newSpeed
                behaviors[car]    = newBehavior
                avoidance[car]    = nil
                politeStopTimes[car] = nil
                refreshCarVisual(car, behavior: newBehavior)
                continue
            }

            // Lane-change avoidance
            if var info = avoidance[car] {
                let f = lateralSmoothingBase + (target/maxSpeed)*0.15
                car.position.x += (info.targetX - car.position.x)*f
                if !info.returning && car.position.y > info.otherCar.position.y { info.returning = true }
                if info.returning {
                    info.targetX = info.originalX
                    if abs(car.position.x - info.originalX) < 1 { avoidance[car] = nil; continue }
                }
                avoidance[car] = info; continue
            }

            // Proactive overtake
            for other in opponents where other != car {
                let dyOther = other.position.y - car.position.y
                let dxOther = abs(other.position.x - car.position.x)
                if dyOther > 0 && dyOther < detectY && dxOther < laneWidth {
                    let oSpd = targetSpeeds[other] ?? target
                    if target > oSpd {
                        for offset in [-laneOffset, laneOffset] {
                            let tx = car.position.x + offset
                            if tx >= xMin && tx <= xMax && isFree(x: tx, y: car.position.y, excluding: car) {
                                avoidance[car] = AvoidanceInfo(originalX: car.position.x, targetX: tx, otherCar: other, returning: false)
                                break
                            }
                        }
                    }
                    break
                }
            }
        }

        // Overlap correction
        for car in opponents {
            for other in opponents where other != car {
                if car.frame.intersects(other.frame) {
                    let corr: CGFloat = car.position.x < other.position.x ? -laneOffset/2 : laneOffset/2
                    car.position.x += corr
                }
            }
        }
    }

    // Refresh the visual child node when a car changes behavior
    private func refreshCarVisual(_ car: SKSpriteNode, behavior: CarBehavior) {
        car.childNode(withName: "carVisual")?.removeFromParent()
        let visual = VisualFactory.makeCarNode(behavior: behavior, size: carSize)
        visual.name = "carVisual"
        visual.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 1.5, duration: 0.3),
            .moveBy(x: 0, y: -1.5, duration: 0.3)
        ])))
        car.addChild(visual)
    }
    
    private func isFree(x tx: CGFloat, y ty: CGFloat, excluding car: SKSpriteNode) -> Bool {
        let frame = CGRect(
            x: tx - carSize.width/2,
            y: ty - carSize.height/2,
            width: carSize.width,
            height: carSize.height
        )
        return !opponents.contains { $0 != car && $0.frame.intersects(frame) }
    }
}
