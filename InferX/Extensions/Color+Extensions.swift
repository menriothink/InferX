//
//  Color+Extensions.swift
//  InferX
//
//  Created by mingdw on 2025/4/4.
//

import SwiftUI
import Foundation

extension Color {
    func adaptiveBackground(for colorScheme: ColorScheme) -> Color {
        #if os(macOS)
        switch colorScheme {
        case .light:
            return Color(nsColor: NSColor.windowBackgroundColor)
        case .dark:
            return Color(nsColor: NSColor.controlBackgroundColor)
        @unknown default:
            return Color(nsColor: NSColor.windowBackgroundColor)
        }
        #else
        switch colorScheme {
        case .light:
            return Color(UIColor.systemBackground)
        case .dark:
            return Color(UIColor.secondarySystemBackground)
        @unknown default:
            return Color(UIColor.systemBackground)
        }
        #endif
    }
    
    func brightnessAdjustment(brightness: Double) -> Color {
        let hsb = toHSB()
        // Ensure the new brightness is within the range [0, 1]
        let adjustedBrightness = max(0.0, min(brightness, 1.0))
        return Color(
            hue: Double(hsb.hue), saturation: Double(hsb.saturation), brightness: adjustedBrightness
        )
    }
    
    func toHSB() -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.black
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation, brightness)
    }
    
    func inferXBackgroundColor(for colorScheme: AppColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return Color.gray.opacity(0.001)
        case .dark:
            return Color.primary.brightnessAdjustment(brightness: 0.2)
        case .system:
            return Color.primary
        }
    }
}

@MainActor
class AppearanceMonitor: ObservableObject {
    var isDarkMode: Bool

    private var observation: NSKeyValueObservation?

    init() {
        self.isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        observation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            }
        }
    }
}
