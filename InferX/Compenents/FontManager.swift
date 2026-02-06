//
//  FontManager.swift
//  InferX
//
//  Created by mingdw on 2025/6/22.
//

import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformFontManager = NSFontManager
#else
import UIKit
typealias PlatformFontManager = UIFont
#endif

struct SystemFont: Identifiable, Hashable {
    let id: String
    let displayName: String
}

class FontManager {
    @MainActor static let shared = FontManager()
    
    private(set) var availableFonts: [SystemFont] = []
    
    private init() {
        self.availableFonts = loadSystemFonts()
    }
    
    private func loadSystemFonts() -> [SystemFont] {
        #if os(macOS)
        let fontFamilies = PlatformFontManager.shared.availableFontFamilies
        return fontFamilies.map { SystemFont(id: $0, displayName: $0) }.sorted { $0.displayName < $1.displayName }
        #else
        let fontFamilies = PlatformFontManager.familyNames.sorted()
        return fontFamilies.map { SystemFont(id: $0, displayName: $0) }
        #endif
    }
    
    static var defaultFont: SystemFont {
        // Keep `displayName` as the localization key so SwiftUI can resolve it
        // using the view hierarchy's `.environment(\.locale, ...)`.
        return SystemFont(id: "System Font", displayName: "System Font")
    }
}
