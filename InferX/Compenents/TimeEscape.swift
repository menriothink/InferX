//
//  TimeEscape.swift
//  InferX
//
//  Created by mingdw on 2025/5/5.
//

import SwiftUI

struct TimeEscapeView: View {
    @Environment(ConversationDetailModel.self) private var detailModel
    
    let messageData: MessageData
    let isBottomMessage: Bool
    let realContent: Bool
    
    @State private var timeTask: Task<Void, Never>?
    @State private var elapsedTimeString: String = "0.00"

    var body: some View {
        Text("Thinking Elapsed: \(elapsedTimeString)")
            .task(id: realContent) {
                elapsedTimeString = messageData.elapsedTimeString ?? "0.000s"
                
                guard isBottomMessage && detailModel.inferring else {
                    stopLocalTimerAndPersist()
                    return
                }
                
                stopLocalTimer()

                timeTask = Task {
                    guard let start = detailModel.startEscapeTime else {
                        stopLocalTimerAndPersist()
                        return
                    }

                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: UInt64(100_000_000))
                        let duration = Date().timeIntervalSince(start)
                        elapsedTimeString = String(format: "%.3fs", duration)
                        
                        var bottomMessage = detailModel.bottomMessage
                        bottomMessage?.elapsedTimeString = elapsedTimeString
                        detailModel.bottomMessage = bottomMessage
                        
                        if realContent || !detailModel.inferring {
                            stopLocalTimerAndPersist()
                            return
                        }
                    }
                }
            }
            .onDisappear {
                stopLocalTimerAndPersist()
            }
    }
    
    private func stopLocalTimerAndPersist() {
        timeTask?.cancel()
        timeTask = nil
    }
    
    private func stopLocalTimer() {
        timeTask?.cancel()
        timeTask = nil
    }
}
