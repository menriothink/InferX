//
//  ConversationInput.swift
//  InferX
//
//  Created by mingdw on 2025/4/26.
//

import SwiftUI
import SwiftData
import Foundation
import UniformTypeIdentifiers
import Defaults

// MARK: - Attachment Data Model
@MainActor
@Observable
final class Attachment: Identifiable, Equatable {
    enum AttachStatus: Sendable {
        case pause
        case uploading
        case done
    }

    let id = UUID()
    let location: URL
    var attachmentData: AttachmentData
    var status: AttachStatus = .pause
    var progress: Progress = Progress()
    var task: Task<Void, Never>? = nil

    var thumbnail: Image? {
        get { Image(data: attachmentData.thumbnail) }
        set { attachmentData.thumbnail = newValue?.toData(size: CGSize(width: 64, height: 64)) }
    }

    init(thumbnail: Image, location: URL, bookmark: Data) {
        self.location = location
        self.attachmentData = AttachmentData(bookmark: bookmark)
        self.thumbnail = thumbnail
    }

    nonisolated static func == (lhs: Attachment, rhs: Attachment) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Conversation Input View
struct ConversationInput: View {
    @Environment(ConversationModel.self) private var conversationModel
    @Environment(ConversationDetailModel.self) private var detailModel
    @Environment(ModelManagerModel.self) private var modelManager
    
    @State private var asistantMessageCache: String = ""
    @State private var messageText: String = ""
    @State private var lastFlushTime: Date = .distantPast
    @State private var attachments: [Attachment] = []
    @State private var isDragOver = false
    @State private var showingDropAlert = false
    @State private var dropAlertMessage = ""
    
    private let flushInterval: TimeInterval = 0.5
    
    private let maxAttachmentSizeMB = 1000
    
    var body: some View {
        ConversationInputBar(
            messageText: $messageText,
            onSend: sendMessage,
            attachments: attachments,
            onAttachAdd: attachAdd,
            onAttachRemove: attachRemove,
            onReAttach: attachReUpload,
            isDragOver: isDragOver
        )
        .overlay(
            Group {
                if isDragOver {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.1)))
                        .animation(.easeInOut(duration: 0.2), value: isDragOver)
                }
            }
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
        .alert("Add Attachment", isPresented: $showingDropAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(dropAlertMessage)
        }
    }
    
    // MARK: - Core Chat Logic
    
    func sendMessage() {
        detailModel.chatTask = Task {
            do {
                // 1. Validate preconditions
                guard let conversation = detailModel.conversation,
                      let model = modelManager.getModel(modelID: conversation.modelID),
                      let modelAPI = modelManager.getModelAPI(modelAPIName: model.apiName)
                else {
                    throw SimpleError(message: "Error during chat: Invalid conversation or model configuration.")
                }
                
                guard model.isAvailable else {
                    throw SimpleError(message: "Error during chat: Model is unreachable. Please refresh its status.")
                }
                
                // 2. Prepare user message and attachments
                let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                let attachmentsData = attachments.compactMap { $0.status == .done ? $0.attachmentData : nil }
                
                guard !trimmedMessage.isEmpty || !attachmentsData.isEmpty else { return }
                
                // 3. Reset UI and state for new message
                self.messageText = ""
                self.asistantMessageCache = ""
                self.attachments.removeAll { $0.status == .done }
                detailModel.inferring = true
                
                // 4. Create and save user message to the database
                guard await MessageData.create(
                    role: .user,
                    content: trimmedMessage,
                    attachmentsData: Dictionary(uniqueKeysWithValues: attachmentsData.map { (UUID(), $0) }),
                    conversationID: conversation.id,
                    modelName: model.name,
                    modelAPIName: model.apiName,
                    modelProvider: model.modelProvider
                ) != nil else {
                    throw SimpleError(message: "Failed to create user message.")
                }
                
                // 5. Create a placeholder for the assistant's response
                guard await MessageData.create(
                    role: .assistant, content: "", conversationID: conversation.id,
                    modelName: model.name, modelAPIName: model.apiName, modelProvider: model.modelProvider
                ) != nil else {
                    throw SimpleError(message: "Failed to create assistant message placeholder.")
                }
                
                withAnimation(.easeInOut(duration: 2.5)) {
                    detailModel.scrollToBottomMessage.toggle()
                }
                conversation.updatedAt = Date.now
                
                var modelParameter = ModelParameter(from: model)
                if conversation.userPromptEnable && !conversation.userPrompt.isEmpty {
                    modelParameter.enableSystemPrompt = true
                    modelParameter.systemPrompt = conversation.userPrompt
                }
                
                // 6. Fetch history and construct the request
                let (_, _, history) = await detailModel.fetchMessages(from: .bottom, numbers: model.inputMessages)
                let chatRequest = try constructChatRequest(
                    for: model,
                    with: history ?? [],
                    modelParameter: modelParameter
                )
                
                // 7. Stream the response from the model
                await streamModelResponse(for: modelAPI, with: chatRequest)
                
            } catch {
                await handleChatFailure(error: error.localizedDescription)
            }
        }
    }
    
    private func constructChatRequest(
        for model: Model,
        with history: [MessageData],
        modelParameter: ModelParameter
    ) throws -> ChatRequest {
        let inputMessages = history.compactMap { message -> ChatRequest.Message? in
            guard message.role != .system,
                  !message.realContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !message.attachmentsData.isEmpty
            else { return nil }
            
            return ChatRequest.Message(
                role: message.role,
                parts: [.text(message.realContent), .attachmentsData(message.attachmentsData)]
            )
        }
        
        return ChatRequest(
            modelName: model.name,
            modelParameter: modelParameter,
            messages: inputMessages
        )
    }
    
    private func streamModelResponse(for modelAPI: ModelAPI, with request: ChatRequest) async {
        await withTaskCancellationHandler {
            await modelManager.modelService.chatModel(
                for: ModelAPIDescriptor(from: modelAPI),
                request: request,
                handler: handleStreamPart
            )
            
            if detailModel.inferring {
                await handleChatFinished()
                print("Chat finished.")
            }
        } onCancel: {
            Task {
                await handleChatFinished()
                print("Chat was cancelled.")
            }
        }
    }
    
    @MainActor
    @Sendable
    private func handleStreamPart(completion: ChatCompletion) async {
        switch completion {
        case .receiving(let chatResponse):
            detailModel.bottomMessage?.chatStatics = chatResponse.chatStatics
            guard let parts = chatResponse.message?.parts else { return }
            
            for part in parts {
                switch part {
                case .text(let text):
                    self.asistantMessageCache.append(text)
                    if self.asistantMessageCache.contains("</think>") &&
                        !self.asistantMessageCache.contains("<think>") {
                        self.asistantMessageCache = "<think>" + self.asistantMessageCache
                    }
                    
                    let now = Date()
                    if now.timeIntervalSince(lastFlushTime) >= flushInterval {
                        detailModel.bottomMessage?.content =
                            self.asistantMessageCache.trimmingCharacters(in: .whitespacesAndNewlines)
                        lastFlushTime = now
                    }
                    //print(self.asistantMessageCache)
                case .inlineMedia(let mimeType, let data):
                    print("Media output: \(mimeType), size: \(data.count) bytes")
                case .fileMedia(let mimeType, let fileUri):
                    print("File output: \(mimeType), URI: \(fileUri)")
                }
            }
        case .finished:
            print("Response stream finished.")
        case .failure(let error):
            await handleChatFailure(error: "Error during chat: \(error.localizedDescription)")
            if let conversation = detailModel.conversation, let model = modelManager.getModel(modelID: conversation.modelID) {
                model.isAvailable = false
            }
        }
    }
    
    private func handleChatFinished() async {
        await saveMessage()
        
        if let conversation = detailModel.conversation,
                conversation.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                conversation.title == Defaults[.defaultTitle] {
            Task.detached(priority: .utility) {
                await generateTitle()
            }
        }
        
        if let extractedTitle = extractContent(
            from: self.asistantMessageCache,
            startTag: "<title>", endTag: "</title>"
        ) {
            detailModel.conversation?.title = extractedTitle
            print("Successfully extracted title using tag: '\(extractedTitle)'")
        }
        
        detailModel.inferring = false
        detailModel.startEscapeTime = nil
        detailModel.scrollToBottomMessage.toggle()
    }
    
    // MARK: - Title Generation
    
    private func generateTitle() async {
        actor TitleAggregator {
            private(set) var title: String = ""
            func append(_ chunk: String) { self.title.append(chunk) }
        }

        do {
            guard let conversation = detailModel.conversation,
                  let model = modelManager.getModel(modelID: conversation.modelID),
                  let modelAPI = modelManager.getModelAPI(modelAPIName: model.apiName)
            else { return }
            
            let (_, _, history) = await detailModel.fetchMessages(from: .bottom, numbers: 6)
            guard var messages = history, !messages.isEmpty else { return }
            
            let titlePrompt = "Please summarize the previous conversation in 25 characters or less, in the language of the conversation."
            messages.append(MessageData(role: .user, content: titlePrompt, conversationID: conversation.id))
            
            let titleRequest = try constructChatRequest(
                for: model,
                with: messages,
                modelParameter: ModelParameter(from: model)
            )
            let aggregator = TitleAggregator()

            print("send title request")
            
            await modelManager.modelService.chatModel(
                for: ModelAPIDescriptor(from: modelAPI),
                request: titleRequest
            ) { completion in
                if case .receiving(let response) = completion,
                   let text = response.message?.parts.first,
                   case .text(let title) = text {
                    Task { await aggregator.append(title) }
                }
            }
            
            let generatedTitle = await aggregator.title
            if !generatedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleanTitle = generatedTitle.replacingOccurrences(of: "\"", with: "")
                await MainActor.run { conversation.title = realContent(cleanTitle) }
            }
        } catch {
            print("Failed to generate title: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Functions
    private func realContent(_ content: String) -> String {
        if let range = content.range(of: "</think>", options: .backwards) {
            return String(content[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return content
    }
    
    private func saveMessage() async {
        guard var bottomMessage = detailModel.bottomMessage else { return }
        
        bottomMessage.content = self.asistantMessageCache.trimmingCharacters(in: .whitespacesAndNewlines)
        if bottomMessage.role == .assistant {
            if !bottomMessage.content.isEmpty {
                await detailModel.updateMessage(bottomMessage)
            } else {
                await detailModel.deleteMessage(bottomMessage.id)
            }
        }
    }
    
    private func extractContent(from text: String, startTag: String, endTag: String) -> String? {
        let pattern = "\(NSRegularExpression.escapedPattern(for: startTag))(.*?)\(NSRegularExpression.escapedPattern(for: endTag))"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let extracted = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                return extracted.isEmpty ? nil : extracted
            }
        } catch {
            print("Failed to create regular expression: \(error.localizedDescription)")
        }
        return nil
    }
    
    // MARK: - Error Handling
    
    private func handleChatFailure(error: String) async {
        await saveMessage()
        if let systemMessage = await MessageData.create(role: .system, content: error, conversationID: detailModel.conversation?.id) {
            detailModel.bottomMessage = systemMessage
            try? await Task.sleep(for: .milliseconds(10))
        }
        detailModel.inferring = false
        detailModel.startEscapeTime = nil
        detailModel.scrollToBottomMessage.toggle()
        print("Chat failed with error: \(error)")
    }
    
    private func handleError(_ error: String) {
        Task { await handleChatFailure(error: error) }
    }
    
    // MARK: - Attachment Handling
    
    @MainActor
    private func attachRemove(id: UUID) {
        if let index = attachments.firstIndex(where: { $0.id == id }) {
            let attachmentToRemove = attachments[index]
            attachmentToRemove.task?.cancel() // Cancel the ongoing upload task
            print("Cancelled upload task for attachment: \(id)")
            attachments.remove(at: index)
        }
    }
    
    @MainActor
    private func attachReUpload(id: UUID) {
        if let index = attachments.firstIndex(where: { $0.id == id }) {
            attachments[index].status = .pause // Ensure the status is correct
            startUpload(forAttachmentAtIndex: index)
            print("Restart upload task for attachment: \(id)")
        }
    }
    
    @MainActor
    private func attachAdd() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = FileManager.default.getSupportedFileTypes() // Use helper method
        
        if panel.runModal() == .OK {
            guard let url = panel.url else {
                dropAlertMessage = "No file URL was selected."
                showingDropAlert = true
                return
            }
            addAttachment(url: url)
        }
    }
    
    /// Create an Attachment object from a URL and generate a thumbnail in the background
    private func createAttachment(from url: URL, bookmark: Data) async -> Attachment? {
        // Thumbnail generation can be time-consuming, so it's done in a background Task
        let thumbnail = await FileManager.default.getThumbnail(from: url)
        guard let thumbnail = thumbnail else { return nil }
        return Attachment(thumbnail: thumbnail, location: url, bookmark: bookmark)
    }
    
    /// Start the attachment upload task
    private func startUpload(forAttachmentAtIndex index: Int) {
        // Ensure the attachment index is valid to avoid out-of-bounds errors
        guard attachments.indices.contains(index) else { return }
        
        let attachment = attachments[index]
        
        // Cancel the old task (if any)
        attachment.task?.cancel()
        
        let uploadTask = Task { @MainActor in // Ensure the task starts on the main actor, but can switch threads internally
            // Necessary model and session checks
            guard let conversation = detailModel.conversation,
                  let model = modelManager.getModel(modelID: conversation.modelID),
                  let modelAPI = modelManager.getModelAPI(modelAPIName: model.apiName) else {
                await handleChatFailure(error: "Cannot start upload: Model API is not set or the session is invalid.")
                // If the upload cannot start, remove the attachment directly
                if attachments.indices.contains(index) && attachments[index].id == attachment.id {
                    attachments.remove(at: index)
                }
                return
            }
            
            // Securely access the file
            var currentBookmark = self.attachments[index].attachmentData.bookmark
            guard let resolvedURL = FileManager.default.getResolvedURL(from: &currentBookmark) else {
                await handleChatFailure(error: "Could not access file, possibly due to permission issues or the file not existing")
                if attachments.indices.contains(index) && attachments[index].id == attachment.id {
                    attachments.remove(at: index)
                }
                return
            }
            
            guard let fileURL = FileManager.default.securityAccessFile(url: resolvedURL) else {
                await handleChatFailure(error: "Could not access file \(resolvedURL.lastPathComponent) due to permission issues")
                if attachments.indices.contains(index) && attachments[index].id == attachment.id {
                    attachments.remove(at: index)
                }
                return
            }
            
            print("uploadFile, 🛑 Started secure access. \(fileURL.lastPathComponent)")
            defer {
                fileURL.stopAccessingSecurityScopedResource()
                print("uploadFile, 🛑 Stopped secure access. \(fileURL.lastPathComponent)")
            }
            
            // Update attachment status to uploading
            self.attachments[index].status = .uploading
            
            let attachmentID = attachment.id
            
            let uploadRequest = FileUploadRequest(
                fileURL: fileURL,
                progressHandler: { uploadProgress in
                    await MainActor.run { // Ensure UI updates are on the main thread
                        if self.attachments.indices.contains(index)
                            && self.attachments[index].id == attachmentID {
                            self.attachments[index].progress = uploadProgress
                        }
                    }
                }
            )
            
            let modelService = ModelService()
            await modelService.uploadFile(
                for: ModelAPIDescriptor(from: modelAPI),
                request: uploadRequest
            ) { completion in
                await MainActor.run { // Ensure UI updates are on the main thread
                    guard self.attachments.indices.contains(index) &&
                            self.attachments[index].id == attachmentID else { return } // The attachment may have been removed
                    
                    switch completion {
                    case .finished(let uri):
                        self.attachments[index].status = .done
                        if let uri {
                            self.attachments[index].attachmentData.url = uri
                            print("✅ Attachment \(attachmentID) uploaded successfully. Remote URI: \(String(describing: uri))")
                        } else {
                            // If the URI is nil, also treat it as an upload failure
                            self.attachments[index].status = .pause
                            handleError("File uploaded successfully but did not return a URI.")
                        }
                    case .failure(let simpleError):
                        self.attachments[index].status = .pause
                        handleError("File upload failed: \(simpleError.localizedDescription)")
                    }
                }
            }
        }
        
        attachments[index].task = uploadTask
    }
    
    // MARK: - Drag & Drop Handling
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let model = modelManager.activeModel,
              let modelMeta = modelManager.getModelMeta(for: model), modelMeta.mediaSupport else {
            self.dropAlertMessage = "The current model does not support multimodal input."
            self.showingDropAlert = true
            return false
        }
        
        var hasValidFiles = false
        
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.dropAlertMessage = "Failed to read file: \(error.localizedDescription)"
                            self.showingDropAlert = true
                            return
                        }
                        guard let fileURL = url else {
                            self.dropAlertMessage = "Invalid file URL."
                            self.showingDropAlert = true
                            return
                        }
                        self.addAttachment(url: fileURL) // Unified attachment adding logic
                    }
                }
                hasValidFiles = true
            }
        }
        
        if !hasValidFiles {
            dropAlertMessage = "Unsupported file type."
            showingDropAlert = true
        }
        return hasValidFiles
    }
    
    /// Unified logic for adding attachments, whether by file picker or drag-and-drop
    @MainActor
    private func addAttachment(url: URL) {
        let supportedTypes = FileManager.default.getSupportedFileTypes()
        let fileExtension = url.pathExtension.lowercased()
        
        let isSupported = supportedTypes.contains { utType in
            if let extensions = utType.tags[.filenameExtension] {
                return extensions.contains(fileExtension)
            }
            return false
        }
        
        guard isSupported else {
            dropAlertMessage = "Unsupported file type: .\(fileExtension)"
            showingDropAlert = true
            return
        }
        
        if attachments.contains(where: { $0.location == url }) {
            dropAlertMessage = "File already exists: \(url.lastPathComponent)"
            showingDropAlert = true
            return
        }
        
        do {
            let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
            if fileSize > maxAttachmentSizeMB * 1024 * 1024 {
                dropAlertMessage = "File is too large, maximum size is \(maxAttachmentSizeMB)MB."
                showingDropAlert = true
                return
            }
        } catch {
            print("Failed to get file size: \(error)")
            dropAlertMessage = "Failed to get file size: \(error.localizedDescription)"
            showingDropAlert = true
            return
        }
        
        guard let bookmark = FileManager.default.getBookmark(for: url) else {
            dropAlertMessage = "Could not create file access permission (Bookmark)."
            showingDropAlert = true
            return
        }
        
        Task { @MainActor in
            guard let newAttachment = await createAttachment(from: url, bookmark: bookmark) else {
                self.dropAlertMessage = "Failed to create attachment: \(url.lastPathComponent)"
                self.showingDropAlert = true
                return
            }
            
            self.attachments.append(newAttachment)
            
            if let index = self.attachments.firstIndex(where: { $0.id == newAttachment.id }) {
                self.startUpload(forAttachmentAtIndex: index)
            }
            
            print("✅ Successfully added file: \(url.lastPathComponent)")
        }
    }
}
