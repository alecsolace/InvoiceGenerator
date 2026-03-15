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

        guard let convertedColor = platformColor.usingColorSpace(.sRGB) else {
            return nil
        }
        convertedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

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

// MARK: - Cross-Platform Design System Colors

extension Color {
    static var cardBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemGroupedBackground)
        #elseif os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color.white
        #endif
    }

    static var appBackground: Color {
        #if os(iOS)
        Color(UIColor.systemGroupedBackground)
        #elseif os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color(.sRGB, white: 0.95, opacity: 1)
        #endif
    }

    static var primaryBackground: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #elseif os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color.white
        #endif
    }
}

// MARK: - Card Style Modifier

extension View {
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.cardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            )
    }

    func materialCardStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            )
    }
}

extension CGColor {
    static func fromHex(_ hex: String, defaultColor: CGColor) -> CGColor {
        Color(hex: hex)?.cgColorRepresentation ?? defaultColor
    }
}
