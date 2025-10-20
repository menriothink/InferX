//
//  ButtonToBottom.swift
//  InferX
//
//  Created by mingdw on 2025/4/6.
//

import SwiftUI

struct ButtonToBottom: View {
    @Environment(\.colorScheme) private var colorScheme    
    @Environment(ConversationDetailModel.self) private var detailModel
    
    @State private var isFlashing: Bool = false
        
    var body: some View {
        Button {
            detailModel.scrollToBottomMessage.toggle()
        } label: {
            Image(systemName: "chevron.down.dotted.2")
                .symbolEffect(.variableColor, isActive: false)
                .opacity(isFlashing ? 0.5 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                    value: isFlashing
                )
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color.black : Color.gray.opacity(0.05))
                        .frame(width: 25, height: 25)
                )
        }
        .onAppear {
            isFlashing = true
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
        .onHover { hovering in
            #if os(macOS)
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
            #endif
        }
        //.frame(width: 40, height: 40)
        .font(.title2)
        .padding(20)
    }
}
