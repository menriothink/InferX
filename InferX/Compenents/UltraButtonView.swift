//
//  UltraButtonView.swift
//  InferX
//
//  Created by mingdw on 2025/5/27.
//

import SwiftUI

struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

struct UltraButtonView: View {
    let fontSize: CGFloat
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                //.kerning(kerning)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.5), Color.gray.opacity(0.8)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.gray.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ModernButtonStyle())
    }
}
