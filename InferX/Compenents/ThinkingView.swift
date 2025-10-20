//
//  ThinkView.swift
//  InferX
//
//  Created by mingdw on 2025/4/27.
//

import SwiftUI
import SwiftUIX
import Defaults

struct ThinkingView: View {
    @Binding var showThink: Bool
    let thinkContent: String?
    let thinkComplete: Bool
    let colorScheme: ColorScheme
    
    @State private var lines: String = ""
        
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showThink.toggle()
                    }
                }) {
                    Image(systemName: showThink ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                Text(thinkComplete ? "Thought completed" : "Thinking...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !thinkComplete {
                    AnimatedTypingDots(maxDots: 1)
                        .frame(width: 24, height: 10)
                }
                Spacer()
            }
            
            VStack {
                if showThink && !lines.isEmpty {
                    Text(thinkComplete ? thinkContent ?? "" : lines)
                        .padding(6)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity)
                        )
                }
            }
            .background(colorScheme == .dark ? .gray.opacity(0.2) : .gray.opacity(0.1))
            .overlay {
                if showThink && !thinkComplete {
                    AppleIntelligenceEffectView(useRoundedRectangle: true)
                        .allowsHitTesting(false)
                        .opacity(Defaults[.appleIntelligenceEffect] ? 0.5 : 0)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .task(id: thinkContent) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    lines = String(thinkContent?.suffix(500) ?? "")
                }
            }
            .onChange(of: thinkComplete) {
                if thinkComplete {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showThink = false
                    }
                }
            }
        }
    }
}
