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
public typealias Color = UIColor
#elseif os(macOS)
import Cocoa
private typealias Color = NSColor
#endif

#if !os(Linux)
private extension Color {
    convenience init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
#endif

public extension Theme {
    static var myCustomDarkTheme: Theme {
        Theme(
            font: .init(size: 16),
            plainTextColor: Color(red: 1.0, green: 1.0, blue: 1.0),
            tokenColors: [
                .keyword: Color(red: 1.0, green: 0.4, blue: 0.7),
                .string: Color(red: 1.0, green: 0.8, blue: 0.5),
                .type: Color(red: 0.4, green: 0.9, blue: 1.0),
                .call: Color(red: 0.2, green: 0.9, blue: 1.0),
                .number: Color(red: 0.8, green: 1.0, blue: 0.8),
                .comment: Color(red: 0.6, green: 0.8, blue: 0.6),
                .property: Color(red: 0.6, green: 0.9, blue: 1.0),
                .dotAccess: Color(red: 1.0, green: 1.0, blue: 0.6),
                .preprocessing: Color(red: 1.0, green: 0.8, blue: 0.6)
            ],
            backgroundColor: Color(red: 0.15, green: 0.15, blue: 0.15)
        )
    }
    
    static var sundellsColors: Theme {
        Theme(
            font: .init(size: 16),
            plainTextColor: Color(red: 0.15, green: 0.15, blue: 0.15),
            tokenColors: [
                .keyword: Color(red: 0.75, green: 0.2, blue: 0.7),
                .string: Color(red: 0.90, green: 0.45, blue: 0.25),
                .type: Color(red: 0.2, green: 0.55, blue: 0.85),
                .call: Color(red: 0.25, green: 0.65, blue: 0.5),
                .number: Color(red: 0.95, green: 0.55, blue: 0.3),
                .comment: Color(red: 0.4, green: 0.55, blue: 0.5),
                .property: Color(red: 0.45, green: 0.75, blue: 0.95),
                .dotAccess: Color(red: 0.45, green: 0.75, blue: 0.95),
                .preprocessing: Color(red: 0.85, green: 0.45, blue: 0.15)
            ],
            backgroundColor: Color(red: 0.15, green: 0.15, blue: 0.15)
        )
    }
        
    
    static var darkTheme: Theme {
        Theme(
            font: .init(size: 16),
            plainTextColor: Color(red: 1.0, green: 1.0, blue: 1.0),
            tokenColors: [
                .keyword: Color(red: 1.0, green: 0.3, blue: 0.6),
                .string: Color(red: 1.0, green: 0.6, blue: 0.2),
                .type: Color(red: 0.2, green: 0.9, blue: 1.0),
                .call: Color(red: 0.0, green: 1.0, blue: 1.0),
                .number: Color(red: 0.6, green: 1.0, blue: 0.6),
                .comment: Color(red: 0.5, green: 0.7, blue: 0.5),
                .property: Color(red: 0.6, green: 0.9, blue: 1.0),
                .dotAccess:  Color(red: 1.0, green: 1.0, blue: 0.4),
                .preprocessing: Color(red: 1.0, green: 0.5, blue: 0.2)
            ],
            backgroundColor: Color(red: 0.15, green: 0.15, blue: 0.15)
        )
    }
}
