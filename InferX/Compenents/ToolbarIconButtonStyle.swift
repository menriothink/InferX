//
//  ToolbarIconButtonStyle.swift
//  InferX
//
//  Created by mingdw on 2025/10/18.
//

import SwiftUI

// MARK: - Custom Button Style for Toolbar
struct ToolbarIconButtonStyle: ButtonStyle {
    var hasBackground: Bool = false
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let backgroundOpacity = if isPressed { 0.15 } else if isHovering { 0.1 } else { hasBackground ? 0.1 : 0 }

        configuration.label
            .font(.title3)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(backgroundOpacity))
            )
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}
