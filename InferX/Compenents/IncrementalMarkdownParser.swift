import SwiftUI

@Observable
final class IncrementalMarkdownParser {
    
    let flushInterval: TimeInterval = 0.5
    let flushIntervalComplete: TimeInterval = 10
    private(set) var completedContent: String = ""
    
    private(set) var streamingContent: String = ""
    
    private var lastProcessedContent: String = ""
    
    private var lastFlushTime: Date = .distantPast
    private var lastFlushTimeComplete: Date = .distantPast
    
    func process(newContent: String) {
        guard newContent.count > lastProcessedContent.count else {
            if newContent.isEmpty { reset() }
            return
        }

        let now = Date()
        var timeSinceLastFlush = now.timeIntervalSince(lastFlushTime)
        if timeSinceLastFlush >= flushInterval {
            let startIndex = newContent.index(newContent.startIndex, offsetBy: lastProcessedContent.count)
            let incrementalChunk = String(newContent[startIndex...])
            lastProcessedContent = newContent
            streamingContent.append(incrementalChunk)
            lastFlushTime = now
        }
        
        timeSinceLastFlush = now.timeIntervalSince(lastFlushTimeComplete)
        if timeSinceLastFlush >= flushIntervalComplete {
            completedContent.append(streamingContent)
            streamingContent = ""
            lastFlushTimeComplete = now
        }
    }
    
    func finalize() {
        if !streamingContent.isEmpty {
            if !completedContent.isEmpty {
                completedContent.append("\n\n")
            }
            completedContent.append(streamingContent)
        }
        streamingContent = ""
        resetTrackers()
    }
    
    func reset() {
        completedContent = ""
        streamingContent = ""
        resetTrackers()
    }
    
    private func resetTrackers() {
        lastProcessedContent = ""
    }

    private func findCompletedBlock(in text: String) -> (String, Int)? {
        if let startRange = text.range(of: "```") {
            let searchRangeAfterStart = startRange.upperBound..<text.endIndex
            if let endRange = text.range(of: "```", range: searchRangeAfterStart) {
                let blockContent = String(text[startRange.lowerBound..<endRange.upperBound])
                
                var separatorLength = 0
                if let charAfter = text[safe: endRange.upperBound], charAfter.isNewline {
                    separatorLength = 1
                } else if text.range(of: "\n\n", range: endRange.upperBound..<text.endIndex)?.lowerBound == endRange.upperBound {
                    separatorLength = 2
                }
                
                return (blockContent, separatorLength)
            }
        }
        
        if let separatorRange = text.range(of: "\n\n") {
            let blockContent = String(text[..<separatorRange.lowerBound])
            if !blockContent.trimmingCharacters(in: .whitespaces).isEmpty {
                return (blockContent, 2)
            }
        }
        
        return nil
    }
}

extension String {
    subscript(safe index: Index) -> Character? {
        return indices.contains(index) ? self[index] : nil
    }
}
