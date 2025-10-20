#if DEBUG
import SwiftUI
import SwiftData

private struct PreviewDataBootstrapper {
    static var complexMarkdown: String {
        let block = (
            [
                "# Level 1 Heading\n",
                "## Level 2 Heading *italic* **bold**\n",
                "> Quote paragraph, including `inline code` and math: $E=mc^2$\n",
                "```swift\nstruct Point { let x: Int; let y: Int }\nfunc add(_ a:Int,_ b:Int)->Int { a+b }\n```\n",
                "- List item A\n- List item B\n  - Subitem 1\n  - Subitem 2\n",
                "1. Item one\n2. Item two\n",
                "| Header | Value |\n| ---- | --- |\n| A | 1 |\n| B | 2 |\n",
                "![Image placeholder](https://example.com/image.png)\n",
                "<think>Chain-of-thought internal reasoning text, should not be directly displayed to the end user, but used for debugging.</think>\n",
                "<title>Automatically generated title example</title>\n",
                "---\n"
            ].joined()
        )
        return block
    }
    
    static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV0.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: config)
    }

    static func seedMessages(count: Int, conversationID: UUID) async {
        for i in 0..<count {
            let role: Role = (i % 2 == 0) ? .user : .assistant
            let content = role == .user ? "User question #\(i)\n\n" + complexMarkdown : "Assistant answer #\(i)\n\n" + complexMarkdown
            
            guard await MessageData.create(
                role: role,
                content: content,
                conversationID: conversationID,
                modelName: "gemini-1.5-pro",
                modelAPIName: "DefaultAPI",
                modelProvider: .gemini
            ) != nil else {
                return
            }
        }
    }
}

struct ConversationContent_InMemoryContainer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            preview(messageCount: 40).previewDisplayName("ConversationContent 40 items")
            preview(messageCount: 500).previewDisplayName("ConversationContent 500 items")
        }
    }

    private static func preview(messageCount: Int) -> some View {
        let container = PreviewDataBootstrapper.makeInMemoryContainer()
        SwiftDataProvider.share.container = container
        SwiftDataProvider.share.messageService = MessageService(modelContainer: container)
            
        let settings = SettingsModel()
        let modelManager = ModelManagerModel()
        
        let conversationModel = ConversationModel()
        conversationModel.createConversation()
        
        guard let conversation = conversationModel.selectedConversation else {
            print("Preview cannot create conversation")
            return AnyView(ConversationContent())
        }
        
        let detailModel = conversationModel.detailModel(for: conversation)
        
        return AnyView(
            ConversationContent()
                .environment(settings)
                .environment(modelManager)
                .environment(conversationModel)
                .environment(detailModel)
                .frame(width: 400, height: 600)
                .task {
                    await PreviewDataBootstrapper.seedMessages(count: messageCount, conversationID: conversation.id)
                    
                    detailModel.scrollToBottomMessage.toggle()
                }
        )
    }
}
#endif
