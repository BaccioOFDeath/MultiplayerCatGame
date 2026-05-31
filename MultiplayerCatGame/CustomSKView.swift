// CustomSKView.swift
import SpriteKit

class CustomSKView: SKView {
    override var canBecomeFocused: Bool { false }
    override func focusItems(in rect: CGRect) -> [UIFocusItem] { [] }
}
