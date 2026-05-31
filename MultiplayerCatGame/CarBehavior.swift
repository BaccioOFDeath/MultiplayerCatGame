// CarBehavior.swift
import SpriteKit

// CarBehavior.swift
enum CarBehavior {
    case cautious, polite, aggressive, impatient, distracted, reckless, lazy, tailgater, rubberneck
}

extension CarBehavior {
    var color: UIColor {
        switch self {
        case .cautious:   return .green
        case .polite:     return .yellow
        case .aggressive: return .red
        case .impatient:  return .orange
        case .distracted: return .cyan
        case .reckless:   return .magenta
        case .lazy:       return .brown
        case .tailgater:  return .purple
        case .rubberneck: return .blue
        }
    }
    var speedFactor: CGFloat {
        switch self {
        case .cautious:   return 0.5
        case .polite:     return 0
        case .aggressive: return 1.2
        case .impatient:  return 1.1
        case .distracted: return CGFloat.random(in: 0.4...0.8)
        case .reckless:   return 1.0
        case .lazy:       return 0.6
        case .tailgater:  return 1.3
        case .rubberneck: return 0.2
        }
    }
    var steerFactor: CGFloat {
        switch self {
        case .cautious:   return 0.05
        case .polite:     return 0.02
        case .aggressive: return 0.2
        case .impatient:  return 0.15
        case .distracted: return 0.03
        case .reckless:   return 0.25
        case .lazy:       return 0
        case .tailgater:  return 0.18
        case .rubberneck: return 0.1
        }
    }
    var politeThreshold: TimeInterval {
        switch self {
        case .polite:     return 5
        default:          return 0
        }
    }
}


struct AvoidanceInfo {
    let originalX: CGFloat
    var targetX: CGFloat
    let otherCar: SKSpriteNode
    var returning: Bool
}
