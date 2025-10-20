//
//  Conversation.swift
//  InferX
//
//  Created by mingdw on 2025/9/18.
//

import Foundation
import Defaults

extension Conversation {
    convenience init(
        title: String = Defaults[.defaultTitle],
        modelID: UUID? = nil,
        userPrompt: String = Defaults[.defaultSystemPrompt]
    ) {
        self.init(
            title: title,
            modelID: modelID,
            createdAt: Date(),
            updateAt: Date(),
            userPrompt: userPrompt,
            userPromptEnable: false
        )
    }
}
