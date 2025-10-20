//
//  Untitled.swift
//  InferX
//
//  Created by mingdw on 2025/4/27.
//

import SwiftUI

struct AnimatedTypingDots: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State private var startTime: TimeInterval = 0.0
    
    var maxDots: Int = 10

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            let currentTime = timeline.date.timeIntervalSinceReferenceDate
            let elapsedTime = currentTime - startTime
            let phase = elapsedTime.truncatingRemainder(dividingBy: 10)
            
            let dotCount = (Int(floor(elapsedTime / 2))) % maxDots + 1
            
            HStack(spacing: 6) {
                ForEach(0..<dotCount, id: \.self) { index in
                    let delay = Double(index) * 0.15
                    let progress = max(0, min(1, CGFloat(sin((phase - delay) * .pi))))
                    Circle()
                        .fill(colorScheme == .dark ? .white.opacity(0.5) : .gray.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .scaleEffect(1 + 0.6 * progress)
                        .opacity(0.5 + 0.5 * progress)
                }
            }
        }
        .onAppear {
            startTime = Date.timeIntervalSinceReferenceDate
        }
    }
}
