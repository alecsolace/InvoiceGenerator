import SwiftUI
import CoreGraphics

#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias PlatformColor = NSColor
#endif

extension Color {
    init?(hex: String) {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard let value = Int(sanitized, radix: 16) else { return nil }

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch sanitized.count {
        case 6:
            red = Double((value >> 16) & 0xFF)
            green = Double((value >> 8) & 0xFF)
            blue = Double(value & 0xFF)
            alpha = 255
        case 8:
            alpha = Double((value >> 24) & 0xFF)
            red = Double((value >> 16) & 0xFF)
            green = Double((value >> 8) & 0xFF)
            blue = Double(value & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: red / 255,
            green: green / 255,
            blue: blue / 255,
            opacity: alpha / 255
        )
    }

    var hexString: String? {
        #if canImport(UIKit)
        let platformColor = PlatformColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
        #elseif canImport(AppKit)
        let platformColor = PlatformColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard let convertedColor = platformColor.usingColorSpace(NSColorSpace.sRGB),
              convertedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
        #else
        return nil
        #endif
    }

    var cgColorRepresentation: CGColor? {
        #if canImport(UIKit) || canImport(AppKit)
        PlatformColor(self).cgColor
        #else
        nil
        #endif
    }
}

extension CGColor {
    static func fromHex(_ hex: String, defaultColor: CGColor) -> CGColor {
        Color(hex: hex)?.cgColorRepresentation ?? defaultColor
    }
}
