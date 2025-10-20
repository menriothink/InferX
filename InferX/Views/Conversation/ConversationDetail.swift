//
//  ConversationDetailView.swift
//  InferX
//
//  Created by mingdw on 2025/4/4.
//

import SwiftUI

struct ConversationDetail: View {
    @Environment(ConversationModel.self) private var conversationModel
    var body: some View {
        VStack(alignment: .center) {
            ConverSationHeaderView()
            ConversationContent()
            ConversationToolBar()
            ConversationInput()
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
