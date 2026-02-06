import SwiftUI

// MARK: - Conversation Toolbar View
struct ConversationToolBar: View {
    @Environment(SettingsModel.self) private var settingsModel
    @Environment(ConversationDetailModel.self) private var detailModel
    @Environment(ConversationModel.self) private var conversationModel
    @Environment(ModelManagerModel.self) var modelManager
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    @State private var addingModel = false
    @State private var selectedModel: Model?
    @State private var iconScale: Bool = false
    @State private var showAlert: Bool = false
    
    @State private var stats = ModelStats()
    
    struct ModelStats {
        var promptTPD: Int = 0
        var completionTPD: Int = 0
        var promptTPM: Int = 0
        var completionTPM: Int = 0
        var requestsPerDay: Int = 0
        var requestsPerMinute: Int = 0
    }

    private var isCompact: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }
    
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        guard let utcTimeZone = TimeZone(secondsFromGMT: 0) else {
            fatalError("UTC TimeZone could not be created.")
        }
        calendar.timeZone = utcTimeZone
        return calendar
    }()
    
    var body: some View {
        VStack(spacing: isCompact ? 0 : 8) {
            if !isCompact {
                statsDisplayView
                Divider()
            }
            controlButtonsView
        }
        .frame(minHeight: isCompact ? 44 : 60)
        .padding(.horizontal, isCompact ? 12 : 15)
        .padding(.vertical, isCompact ? 6 : 8)
        .onChange(of: selectedModel) { oldValue, newValue in
            guard oldValue?.id != newValue?.id else { return }
            detailModel.conversation?.modelID = newValue?.id
            modelManager.activeModel = selectedModel
            updateTokens()
        }
        .onChange(of: detailModel.inferring) { _, isInferring in
            if !isInferring {
                updateTokens()
            }
        }
        .onAppear {
            initializeSelectedModel()
            updateTokens()
        }
        .sheet(isPresented: $addingModel) {
            ModelAddSheetView()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var statsDisplayView: some View {
        Group {
            if isCompact {
                HStack(spacing: 0) {
                    Text("RPD:\(stats.requestsPerDay) RPM:\(stats.requestsPerMinute)")
                    Spacer()
                    Text("In:\(stats.promptTPD)/\(stats.promptTPM)")
                    Text("  Out:\(stats.completionTPD)/\(stats.completionTPM)")
                }
            } else {
                HStack(spacing: 15) {
                    Spacer()
                    Text("RPD: \(stats.requestsPerDay)")
                    Text("RPM: \(stats.requestsPerMinute)")
                    Text("Input [ TPD: \(stats.promptTPD)  TPM: \(stats.promptTPM) ]")
                    Text("Output [ TPD: \(stats.completionTPD)  TPM: \(stats.completionTPM) ]")
                }
            }
        }
        .font(isCompact ? .caption2 : .caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    
    @ViewBuilder
    private var controlButtonsView: some View {
        #if os(iOS)
        HStack(spacing: 6) {
            toolbarButtonsCompact
        }
        #else
        HStack(spacing: 0) {
            toolbarButtons
        }
        #endif
    }
    
    @ViewBuilder
    private var toolbarButtons: some View {
            Button {
                detailModel.mardDownEnable.toggle()
                detailModel.toastMessage = detailModel.mardDownEnable ? "Markdown format is enabled" : "Markdown format is disabled"
                detailModel.showToast.toggle()
            } label: { Image(systemName: detailModel.mardDownEnable ? "doc.richtext.fill" : "doc.text") }
            .buttonStyle(ToolbarIconButtonStyle())
            .help("Toggle Markdown Format")

            Button {
                Task {
                    detailModel.scrollToBottomMessage.toggle()
                    try? await Task.sleep(for: .milliseconds(500))
                    withAnimation(.easeInOut) { detailModel.foldEnable.toggle() }
                    detailModel.toastMessage = detailModel.foldEnable ? "Message fold is enabled" : "Message fold is disabled"
                    detailModel.showToast.toggle()
                }
            } label: { Image(systemName: detailModel.foldEnable ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") }
            .buttonStyle(ToolbarIconButtonStyle())
            .help("Toggle Message Folding")

            Button {
                showAlert = true
            } label: {
                Image(systemName: "paintbrush")
                    .rotationEffect(.degrees(iconScale ? -45 : 0))
                    .scaleEffect(iconScale ? 1.2 : 1.0)
            }
            .buttonStyle(ToolbarIconButtonStyle())
            .alert("Confirm Deletion", isPresented: $showAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: cleanMessages)
            } message: {
                Text("Are you sure you want to delete conversation messages?")
            }
            .help("Clear All Messages")

            Spacer()
            
            modelSelectView
    }

    #if os(iOS)
    @ViewBuilder
    private var toolbarButtonsCompact: some View {
        HStack(spacing: 0) {
            // Left: action buttons - equal spacing
            HStack(spacing: 16) {
                Button {
                    detailModel.mardDownEnable.toggle()
                    detailModel.toastMessage = detailModel.mardDownEnable ? "Markdown format is enabled" : "Markdown format is disabled"
                    detailModel.showToast.toggle()
                } label: {
                    Image(systemName: detailModel.mardDownEnable ? "doc.richtext.fill" : "doc.text")
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        detailModel.scrollToBottomMessage.toggle()
                        try? await Task.sleep(for: .milliseconds(500))
                        withAnimation(.easeInOut) { detailModel.foldEnable.toggle() }
                        detailModel.toastMessage = detailModel.foldEnable ? "Message fold is enabled" : "Message fold is disabled"
                        detailModel.showToast.toggle()
                    }
                } label: {
                    Image(systemName: detailModel.foldEnable ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button {
                    showAlert = true
                } label: {
                    Image(systemName: "paintbrush")
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                        .rotationEffect(.degrees(iconScale ? -45 : 0))
                        .scaleEffect(iconScale ? 1.2 : 1.0)
                }
                .buttonStyle(.plain)
                .alert("Confirm Deletion", isPresented: $showAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive, action: cleanMessages)
                } message: {
                    Text("Are you sure you want to delete conversation messages?")
                }
            }

            Spacer()

            // Right: model selector - fixed right alignment
            HStack(spacing: 8) {
                // Status indicator
                Circle()
                    .fill(selectedModel?.isAvailable ?? false ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                    .symbolEffect(.variableColor, isActive: detailModel.inferring)

                // Model name as menu trigger
                Menu {
                    Button {
                        selectedModel = nil
                    } label: {
                        if selectedModel == nil {
                            Label("Not selected", systemImage: "checkmark")
                        } else {
                            Text("Not selected")
                        }
                    }

                    Divider()

                    let sortedLocalModels = modelManager.localModels.sorted { $0.key < $1.key }
                    ForEach(sortedLocalModels, id: \.key) { apiName, models in
                        Menu {
                            ForEach(models.sorted { $0.name < $1.name }) { model in
                                Button {
                                    selectedModel = model
                                } label: {
                                    if selectedModel?.id == model.id {
                                        Label(model.name, systemImage: "checkmark")
                                    } else {
                                        Text(model.name)
                                    }
                                }
                            }
                        } label: {
                            Text(apiName)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedModel?.name ?? "Select Model")
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
                .disabled(detailModel.inferring)

                // Separator
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 16)

                // Settings
                Button {
                    guard let activeModel = selectedModel else { return }
                    withAnimation(.easeInOut) {
                        settingsModel.selectedItem = .modelAPIManager
                        modelManager.selectedItem = .modelDetail
                        modelManager.activeModel = activeModel
                        modelManager.activeModelAPI = modelManager.modelAPIs.first {
                            $0.name == activeModel.apiName
                        }
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(detailModel.inferring || selectedModel == nil)

                // Add
                Button { addingModel = true } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(detailModel.inferring)
            }
        }
        .frame(height: 32)
    }
    #endif

    @ViewBuilder
    private var modelSelectView: some View {
        HStack(spacing: 0) {
            if let tab = matchedTab(modelProvider: selectedModel?.modelProvider) {
                tab.iconView()
                    .padding(.horizontal, 10)
                    .font(.footnote)
            }
            
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundStyle(selectedModel?.isAvailable ?? false ? .green : .red)
                .symbolEffect(.variableColor, isActive: detailModel.inferring)
                .help("Model State")
                .padding(.leading, 5)
            
            Picker("Select Model", selection: $selectedModel) {
                Text("Not selected").tag(nil as Model?)
                
                let sortedLocalModels = modelManager.localModels.sorted { $0.key < $1.key }
                ForEach(sortedLocalModels, id: \.key) { apiName, models in
                    Section(header: Text(apiName).font(.headline)) {
                        ForEach(models.sorted { $0.name < $1.name }) { model in
                            Text(model.name)
                                .tag(model as Model?)
                                .lineLimit(1)
                                .help(model.providerRaw)
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
            .labelsHidden()
            .frame(alignment: .trailing)
            .padding(.horizontal, 4)
            .disabled(detailModel.inferring)
            
            Divider().frame(height: 16)

            Button {
                guard let activeModel = selectedModel else { return }
                withAnimation(.easeInOut) {
                    settingsModel.selectedItem = .modelAPIManager
                    modelManager.selectedItem = .modelDetail
                    modelManager.activeModel = activeModel
                    modelManager.activeModelAPI = modelManager.modelAPIs.first {
                        $0.name == activeModel.apiName
                    }
                }
            } label: {
                Image(systemName: "gearshape.circle")
            }
            .buttonStyle(ToolbarIconButtonStyle())
            .opacity(detailModel.inferring ? 0.5 : 1.0)
            .disabled(detailModel.inferring || selectedModel == nil)
            .help("Edit Selected Model")
            
            Divider().frame(height: 16)

            Button {
                addingModel = true
            } label: { Image(systemName: "plus") }
            .buttonStyle(ToolbarIconButtonStyle())
            .opacity(detailModel.inferring ? 0.5 : 1.0)
            .disabled(detailModel.inferring)
            .help("Add New Model")
        }
        .frame(height: 32)
    }
    
    // MARK: - Helper Functions
    
    private func initializeSelectedModel() {
        if let convModelID = detailModel.conversation?.modelID,
           let model = modelManager.getModel(modelID: convModelID) {
            selectedModel = model
        } else {
            selectedModel = modelManager.localModels.values.first?.first
        }
        
        modelManager.activeModel = selectedModel
    }
    
    private func updateTokens() {
        guard let currentModel = self.selectedModel else {
            stats = ModelStats()
            return
        }

        let modelName = currentModel.name
        let modelApiName = currentModel.apiName

        Task {
            let now = Date.now
            let todayStart = Self.utcCalendar.startOfDay(for: now)
            let lastMinuteStart = now.addingTimeInterval(-60)
            
            async let dayStats = detailModel.fetchChatStaticForModel(
                from: todayStart,
                to: now,
                modelName: modelName,
                modelAPIName: modelApiName,
                role: .assistant
            )
            
            async let minuteStats = detailModel.fetchChatStaticForModel(
                from: lastMinuteStart,
                to: now,
                modelName: modelName,
                modelAPIName: modelApiName,
                role: .assistant
            )
            
            let (promptTPD, completionTPD, rpd) = await dayStats
            let (promptTPM, completionTPM, rpm) = await minuteStats
            
            await MainActor.run {
                self.stats = ModelStats(
                    promptTPD: promptTPD, completionTPD: completionTPD,
                    promptTPM: promptTPM, completionTPM: completionTPM,
                    requestsPerDay: rpd, requestsPerMinute: rpm
                )
            }
        }
    }
    
    private func cleanMessages() {
        Task {
            withAnimation(.bouncy(duration: 0.4)) { iconScale = true }
            await detailModel.deleteAllMessages()
            detailModel.scrollToBottomMessage.toggle()
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.bouncy(duration: 0.4)) { iconScale = false }
            detailModel.toastMessage = "Messages are cleaned"
            detailModel.showToast.toggle()
        }
    }
}
