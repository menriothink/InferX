# InferX Copilot Instructions

## Project Overview
**InferX** is a macOS AI chat application supporting multiple LLM providers (Ollama, Gemini, HuggingFace, MLX). It features real-time streaming responses, rich markdown rendering, code syntax highlighting, and multi-provider model management.

**Key Stack**: SwiftUI, Swift 6.0, SwiftData, SwiftUIIntrospect, MarkdownUI

---

## Architecture & Data Flow

### Multi-Layer Architecture
```
Views (SwiftUI) → ViewModels (@Observable) → Services (Actors) → Data Layer (SwiftData)
```

**Critical Pattern**: Views bind to `@Observable` ViewModels (Swift 5.9+ observation) which coordinate with service layer and SwiftData models. Services use **actor isolation** for thread safety (Swift 6.0).

### Core Service Boundary Pattern
All external API interactions use a **protocol-based factory pattern**:
- `ModelService` is the abstract base for all LLM providers
- Implementations: `OllamaService`, `GeminiService`, `HuggingFaceService` (each an `actor`)
- Services define stream completion enums: `ChatCompletion`, `ModelsCompletion`, `FileUploadCompletion`
- Usage: `await service.handler(.receiving(chatResponse))` for streaming responses

### Data Persistence Pattern
- **SwiftDataProvider**: Singleton managing `ModelContainer` and `MessageService`
- **Schema Versioning**: Uses `SchemaV0` with `AppMigrationPlan` for versioned data migrations
- **Message Pagination**: `MessageService` handles pagination with configurable page sizes based on render mode
- **Critical**: Always use `@MainActor` for UI-bound data operations; use `ReadWriteLock` actor for concurrent reads

### Conversation Flow Architecture
1. **ConversationModel**: Manages conversation list, CRUD operations, search state
2. **ConversationDetailModel**: Handles single conversation, message streaming, attachment state
3. **Message Rendering Chain**: 
   - `StreamingMarkdownView` → `IncrementalMarkdownParser` (buffers content with 0.5s flush interval)
   - Specialized renderers: `CodeBlockView`, `MathWebView`, `MermaidParser`
   - `RenderMessageContent` coordinates type-specific rendering

---

## Critical Concurrency Patterns (Swift 6.0)

### Actor Isolation Rules
- **Services are actors**: `OllamaService`, `GeminiService` are `actor` types (NOT `@MainActor`)
- **UI models are MainActor**: `@MainActor @Observable final class ConversationDetailModel`
- **Never call service methods directly from @MainActor context**: Use `await` with proper isolation
- **ReadWriteLock actor**: Custom actor for concurrent read access with exclusive write locks

### @Sendable Closures
Model service handler signatures require `@Sendable`: 
```swift
handler: @escaping @Sendable (ChatCompletion) async -> Void
```

### Best Practices
- Use `async/await` exclusively, no completion handlers in new code
- Avoid `@unchecked Sendable`; prefer explicit actor isolation
- Task groups for concurrent operations: `withTaskGroup(of: RemoteModel?.self)`
- Use `withCheckedContinuation` for bridging to DispatchSemaphore

---

## Project-Specific Patterns

### Streaming Content Handling
- Messages stream incrementally through `IncrementalMarkdownParser`
- Parser batches updates: 0.5s for streaming chunks, 10s for completion
- `StreamingMarkdownView` applies 0.008s character delay for UI animation
- Used in `ConversationDetailModel.inferring` state machine

### Markdown Rendering Customization
- Theme system in `MarkdownTheme`: light/dark, configurable font sizes/weights
- `Defaults` package for persistent UI preferences (`@Default(.fontSizeBlack)`)
- Code highlighting: `Splash.Theme` integration in `StreamingMarkdownView`

### Multi-Provider Model Meta
`ModelMeta` struct contains 30+ optional fields:
- Limits: `inputTokenLimit`, `outputTokenLimit`, `baseContextLength`
- Parameters: `temperature`, `topP`, `topK`, `repetitionPenalty`
- Capabilities: `thinking`, `mediaSupport`, `seed`, `chatTemplate`
- RoPE configuration: `ropeType`, `ropeFactor`, `ropeBetaFast`, `ropeBetaSlow`

### Attachment System
- `MessageAttachmentView` handles image/document previews
- `ContentProcessor` extracts and validates attachments
- UUID-keyed: `[UUID: AttachmentData]?` in message models
- API uploading uses `FileUploadCompletion` enum pattern

### Search & Filtering
- `ConversationModel` manages global search across conversations
- `ConversationDetailModel.searchText` filters messages in detail view
- Full-text search backend via `MessageService.queryMessages()`

---

## Building & Testing

### Build Configuration
- **Swift 6.0** enabled for Main target (strict concurrency checking)
- **Swift 5.0** for test targets (uses older Testing framework comment blocks)
- SPM dependencies auto-downloaded by Xcode

### Test Patterns
Tests currently commented in Swift 5.0 style (`@Test` from new Testing framework):
- See `LLModelServiceTests.swift` for mock loader patterns
- `OllamaServiceTests.swift` tests service responses

### Key Build Artifacts
- `InferX.entitlements`: Sandbox/network permissions
- `Localizable.xcstrings`: Localization strings (SwiftUI native)
- Assets cached in `Assets.xcassets/` (icons, images, colors)

---

## Common Development Tasks

### Adding a New LLM Provider
1. Create `XyzService.swift` as `actor` conforming to service pattern
2. Implement: `getModels()`, `chat()`, `uploadFile()` (if needed)
3. Define provider response types (e.g., `OllamaModelResponse`)
4. Register in `ModelManagerModel.serviceRegistry()`
5. Add UI in `ModelManager/` views

### Adding Message Features
1. Extend `Message` model in `SwiftDataModels/SchemaV0/`
2. Update `MessageService` queries if needed
3. Create specialized renderer (extends `RenderMessageContent`)
4. Add preview in `ConversationDetailModel`

### Streaming Response Handling
1. Use `@Sendable` handler pattern (see `OllamaService.chat()`)
2. Call `handler(.receiving(ChatResponse))` for each chunk
3. Call `handler(.finished)` on completion
4. ViewModels append to `message.content` via `IncrementalMarkdownParser`

### UI State Management
- Prefer `@Observable` final classes with clear property documentation
- Use computed properties for derived state (e.g., `messagesPageSize`)
- Avoid multiple sources of truth for render state

---

## Known Issues & Workarounds

### Concurrency Audit Status
- Project audited for Swift 6.0 compliance (see `.github/CONCURRENCY_AUDIT.md`)
- Fixed: Removed unsafe `@unchecked Sendable`, proper actor isolation
- ReadWriteLock provides safe concurrent reads to SwiftData

### Build Optimization
- SPM dependency caching reduces build time 40-70% (see `.github/CACHE_OPTIMIZATION.md`)
- DerivedData cache strategy: reuse across builds

### SSH Setup for Private Dependencies
- If using private Swift packages, see `.github/SSH_SETUP.md`
- Requires SSH key configuration for GitHub authentication

---

## File Organization Notes

**Naming Typo**: Component directory named `Compenents/` (not `Components/`) - preserve for XCP references

**Data Models**: SwiftData schemas in `SwiftDataModels/SchemaV0/` - add new versions alongside, never modify existing

**View Hierarchy**: Deep nesting in `Views/Conversation/` - keep related views grouped, use `ConversationRightSidebar`, etc. for major sections

---

## Useful File References

- **Architecture**: `README.md` (§ Project Architecture, § Core Modules)
- **Concurrency**: `.github/CONCURRENCY_AUDIT.md`, `.github/SWIFT6_CONCURRENCY_FIXES.md`
- **Service Pattern**: `InferX/LLModelServices/ModelService.swift`, `OllamaService.swift`
- **VM Pattern**: `InferX/ViewModels/ConversationDetailModel.swift`, `ModelManagerModel.swift`
- **Rendering**: `InferX/Compenents/StreamingMarkdownView.swift`, `IncrementalMarkdownParser.swift`
- **Data**: `InferX/SwiftDataServices/SwiftDataProvider.swift`, `SwiftDataModels/Conversation+Extensions.swift`
