//
//  Defaults+Extensions.swift.swift
//  InferX
//
//  Created by mingdw on 2025/3/6.
//

import Defaults
import SwiftUI
import AppKit.NSFont

extension Defaults.Keys {
    static let proxyEnable = Key<Bool>("proxyEnable", default: false)
    static let proxyHost = Key<String>("proxyHost", default: "")
    static let proxyPort = Key<String>("proxyPort", default: "")
    static let ignorHost = Key<String>("ignorHost", default: "localhost, 127.0.0.1")
    static let defaultModel = Key<String>("defaultModel", default: "")
    static let defaultModelProvider = Key<String>("defaultModelProvider", default: "")
    static let language = Key<Language>("language", default: .english)
    static let backgroundContentLightRadius = Key<CGFloat>("backgroundContentLightRadius", default: 0.5)
    static let backgroundContentDarkRadius = Key<CGFloat>("backgroundContentDarkRadius", default: 0.5)
    static let backgroundColorWhite = Key<CGFloat>("backgroundColorWhite", default: 0.5)
    static let backgroundColorBlack = Key<CGFloat>("backgroundColorBlack", default: 0.1)
    static let fontWeightBlack = Key<FontWeightOption>("fontWeightBlack", default: FontWeightOption.semibold)
    static let fontWeightWhite = Key<FontWeightOption>("fontWeightWhite", default: FontWeightOption.light)
    static let fontSizeBlack = Key<CGFloat>("fontSizeBlack", default: 12.0)
    static let fontSizeWhite = Key<CGFloat>("fontSizeWhite", default: 12.0)
    static let fontNameWhite = Key<String>("fontNameWhite", default: "System Font")
    static let fontNameBlack = Key<String>("fontNameBlack", default: "System Font")
    static let fontColorDataBlack = Key<Data?>("fontColorDataBlack", default: nil)
    static let fontColorDataWhite = Key<Data?>("fontColorDataWhite", default: nil)
    static let appColorScheme = Key<AppColorScheme>("appColorScheme", default: .system)

    static let defaultTitle = Key<String>("defaultTitle", default: "Default Conversation")
    static let gpuCacheLimitEnable = Key<Bool>("gpuCacheLimitEnable", default: false)
    static let gpuCacheLimit = Key<Double>("gpuCacheLimit", default: 8196)
}

extension Defaults.Keys {
    static let defaultChatName = Key<String>("defaultChatName", default: "New Chat")
    static let modelDirectoryBookmark = Key<Data?>("modelDirectoryBookmark")
    static let experimentalCodeHighlighting = Key<Bool>("experimentalCodeHighlighting", default: false)
}

extension Defaults.Keys {
    static let defaultUseCustomSettings = Key<Bool>("defaultUseCustomSettings", default: false)
    static let defaultPrompt = Key<String>("defaultPrompt", default: "")
    static let defaultBearerToken = Key<String>("defaultBearerToken", default: "")
    static let defaultTemperature = Key<Float>("defaultTemperature", default: 0.8)
    static let defaultTopP = Key<Float>("defaultTopP", default: 0.8)
    static let defaultTopK = Key<Float>("defaultTopK", default: 0.8)
    static let defaultMaxLength = Key<Int>("defaultMaxLength", default: 1000000)
    static let defaultRepetitionContextSize = Key<Int>("defaultRepetitionContextSize", default: 20)
    static let defaultMaxMessagesLimit = Key<Int>("defaultMaxMessagesLimit", default: 50)
    static let defaultRepetitionPenalty = Key<Float>("defaultRepetitionPenalty", default: 1.0)
}

extension Defaults.Keys {
    static let defaultUseSystemPrompt = Key<Bool>("defaultUseSystemPrompt", default: true)
    static let defaultSystemPrompt = Key<String>(
        "defaultSystemPrompt",
        default:
"""
You are a helpful AI assistant. Follow these system instructions:
1. The user will send multiple historical messages. Review them before each response.
2. If there is only one message with role user, it is the first turn of a new conversation.
    First, return a title for this conversation. Start the title with "<title>" and end it with "</title>".
    Your main response should follow the title. If there are multiple messages, do not return a title.
3. If possible, enclose your thinking process within "<think>" and "</think>" tags.
4. Output your code, and keep it within 200 lines in a single code block. If there are more than one code block, please separate them.
"""
)
    static let defaultEnableThinking = Key<Bool>("defaultEnableThinking", default: true)
    static let defaultThinkingTags = Key<String>(
                                        "defaultThinkingTags",
                                        default: "<|thinking|> <|end_thinking|>, <thinking> </thinking>"
                                    )
    static let defaultCache = Key<Int>("defaultCache", default: 10 * 1024)
    static let defaultSeed = Key<Float>("defaultSeed", default: 1000)
    
    static let appleIntelligenceEffect = Key<Bool>("appleIntelligenceEffect", default: false)
}
