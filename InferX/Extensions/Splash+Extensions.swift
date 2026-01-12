//
//  Spash+Extensions.swift
//  ChatMLX
//
//  Created by mingdw on 2025/3/23.
//

import Splash
import SwiftUI

#if os(iOS)
import UIKit
private typealias SplashPlatformColor = UIColor
#elseif os(macOS)
import Cocoa
private typealias SplashPlatformColor = NSColor
#endif

#if !os(Linux)
private extension SplashPlatformColor {
    convenience init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
#endif

public extension Theme {
    static var myCustomDarkTheme: Theme {
        Theme(
            font: .init(size: 16),
            plainTextColor: SplashPlatformColor(red: 1.0, green: 1.0, blue: 1.0),
            tokenColors: [
                .keyword: SplashPlatformColor(red: 1.0, green: 0.4, blue: 0.7),
                .string: SplashPlatformColor(red: 1.0, green: 0.8, blue: 0.5),
                .type: SplashPlatformColor(red: 0.4, green: 0.9, blue: 1.0),
                .call: SplashPlatformColor(red: 0.2, green: 0.9, blue: 1.0),
                .number: SplashPlatformColor(red: 0.8, green: 1.0, blue: 0.8),
                .comment: SplashPlatformColor(red: 0.6, green: 0.8, blue: 0.6),
                .property: SplashPlatformColor(red: 0.6, green: 0.9, blue: 1.0),
                .dotAccess: SplashPlatformColor(red: 1.0, green: 1.0, blue: 0.6),
                .preprocessing: SplashPlatformColor(red: 1.0, green: 0.8, blue: 0.6)
            ],
            backgroundColor: SplashPlatformColor(red: 0.15, green: 0.15, blue: 0.15)
        )
    }
    
    static var sundellsColors: Theme {
        Theme(
            font: .init(size: 16),
            plainTextColor: SplashPlatformColor(red: 0.15, green: 0.15, blue: 0.15),
            tokenColors: [
                .keyword: SplashPlatformColor(red: 0.75, green: 0.2, blue: 0.7),
                .string: SplashPlatformColor(red: 0.90, green: 0.45, blue: 0.25),
                .type: SplashPlatformColor(red: 0.2, green: 0.55, blue: 0.85),
                .call: SplashPlatformColor(red: 0.25, green: 0.65, blue: 0.5),
                .number: SplashPlatformColor(red: 0.95, green: 0.55, blue: 0.3),
                .comment: SplashPlatformColor(red: 0.4, green: 0.55, blue: 0.5),
                .property: SplashPlatformColor(red: 0.45, green: 0.75, blue: 0.95),
                .dotAccess: SplashPlatformColor(red: 0.45, green: 0.75, blue: 0.95),
                .preprocessing: SplashPlatformColor(red: 0.85, green: 0.45, blue: 0.15)
            ],
            backgroundColor: SplashPlatformColor(red: 0.15, green: 0.15, blue: 0.15)
        )
    }
        
    
    static var darkTheme: Theme {
        Theme(
            font: .init(size: 16),
            plainTextColor: SplashPlatformColor(red: 1.0, green: 1.0, blue: 1.0),
            tokenColors: [
                .keyword: SplashPlatformColor(red: 1.0, green: 0.3, blue: 0.6),
                .string: SplashPlatformColor(red: 1.0, green: 0.6, blue: 0.2),
                .type: SplashPlatformColor(red: 0.2, green: 0.9, blue: 1.0),
                .call: SplashPlatformColor(red: 0.0, green: 1.0, blue: 1.0),
                .number: SplashPlatformColor(red: 0.6, green: 1.0, blue: 0.6),
                .comment: SplashPlatformColor(red: 0.5, green: 0.7, blue: 0.5),
                .property: SplashPlatformColor(red: 0.6, green: 0.9, blue: 1.0),
                .dotAccess:  SplashPlatformColor(red: 1.0, green: 1.0, blue: 0.4),
                .preprocessing: SplashPlatformColor(red: 1.0, green: 0.5, blue: 0.2)
            ],
            backgroundColor: SplashPlatformColor(red: 0.15, green: 0.15, blue: 0.15)
        )
    }
}
