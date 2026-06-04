import AppKit
import SwiftUI

enum VeilHardwareBlack {
    static let red: Double = 0
    static let green: Double = 0
    static let blue: Double = 0
    static let notchEdgeCoverageOpacity: Double = 0.18

    static var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    static var nsColor: NSColor {
        NSColor(
            srgbRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: 1
        )
    }

    static var cgColor: CGColor {
        nsColor.cgColor
    }
}
