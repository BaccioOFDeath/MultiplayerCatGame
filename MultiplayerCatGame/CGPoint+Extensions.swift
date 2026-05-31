// CGPoint+Extensions.swift
import Foundation
import CoreGraphics

extension CGPoint {
    func lerp(to other: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(x: x + (other.x - x) * t,
                y: y + (other.y - y) * t)
    }
}
