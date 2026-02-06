//
//  OllamaView.swift
//  InferX
//
//  Created by mingdw on 2025/4/15.
//

import SwiftUI
import SwiftData
import Defaults

struct ModelAPIDetailView: View {
    @Environment(ModelManagerModel.self) var modelManager

    @Bindable var modelAPI: ModelAPI

    @State private var addingModel = false
    @State private var selectedModel: Model?
    @State private var showingDeleteTaskAlert = false
    @State private var errorShow: String = ""
    
    private var sortedModels: [Model] {
        let models = modelManager.localModels[modelAPI.name] ?? []
        return models.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Model API Settings").font(.headline)) {
                #if os(iOS)
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Model Provider") {
                        HStack(spacing: 6) {
                            modelProviderIcon
                            Text(modelAPI.modelProvider.id)
                        }
                    }
                    
                    LabeledContent("Creation Date") {
                        Text(modelAPI.createdAt.toFormatted(style: .long))
                    }
                    
                    if modelAPI.modelProvider == .copilot {
                        CopilotAuthStatusView(apiId: modelAPI.id)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Server URL").font(.subheadline).foregroundStyle(.secondary)
                            TextField("Server URL", text: $modelAPI.endPoint, onCommit: updateModelStatus)
                                .textContentType(.URL)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("API Key").font(.subheadline).foregroundStyle(.secondary)
                            SecureField("API Key", text: $modelAPI.apiKey, onCommit: updateModelStatus)
                                .textContentType(.password)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                #else
                VStack(alignment: .leading) {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 15) {
                        HStack {
                            Text("Model Provider")
                            Spacer()
                            matchedTab(modelProvider: modelAPI.modelProvider)?.iconView()
                                .padding(.leading, 10)
                            Text(modelAPI.modelProvider.id)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("Creation Date")
                            Spacer()
                            Text(modelAPI.createdAt.toFormatted(style: .long))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if modelAPI.modelProvider == .copilot {
                            CopilotAuthStatusView(apiId: modelAPI.id)
                        } else {
                            HStack {
                                Text("Server URL")
                                Spacer()
                                TextField(text: $modelAPI.endPoint, onCommit: updateModelStatus)
                                    .textContentType(.URL)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .lineLimit(1)
                            }
                            
                            HStack {
                                Text("API Key")
                                Spacer()
                                SecureField(text: $modelAPI.apiKey, onCommit: updateModelStatus)
                                    .textContentType(.password)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                #endif
            }

            Section(header: Text("Model Settings").font(.headline)) {
                #if os(iOS)
                modelListHeader
                
                if !errorShow.isEmpty {
                    Text(errorShow)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                if sortedModels.isEmpty {
                    Text("No models added for this API.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                } else {
                    ForEach(sortedModels) { localModel in
                        NavigationLink {
                            ModelDetailView(model: localModel)
                                .navigationTitle(localModel.name)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            modelRowLabel(localModel)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelManager.deleteModel(model: localModel)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            NavigationLink {
                                ModelDetailView(model: localModel)
                                    .navigationTitle(localModel.name)
                                    .navigationBarTitleDisplayMode(.inline)
                            } label: {
                                Label("Settings", systemImage: "gearshape")
                            }
                            .tint(.blue)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                modelManager.deleteModel(model: localModel)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                #else
                VStack(alignment: .leading, spacing: 10) {
                    modelListHeader
                    
                    if !errorShow.isEmpty {
                        Text(errorShow)
                            .font(.headline)
                            .foregroundStyle(.red)
                            .padding(50)
                    }
                    
                    Divider()
                    localModelList
                }
                #endif
            }
        }
        .foregroundColor(.primary)
        .accentColor(.primary)
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .onAppear {
            modelManager.activeModelAPI = modelAPI
            modelManager.selectedItem = .modelAPIDetail
        }
        .sheet(isPresented: $addingModel) {
            ModelAddSheetView(inputApiName: modelAPI.name)
        }

    }
        
    private var modelListHeader: some View {
        #if os(iOS)
        modelListHeaderContentCompact
        #else
        HStack(spacing: 5) {
            modelListHeaderContent
        }
        #endif
    }

    @ViewBuilder
    private var modelListHeaderContent: some View {
        Text("Model List")
            .padding(.trailing, 10)

        Button(action: updateModelStatus) {
            Image(systemName: "arrow.trianglehead.clockwise.rotate.90")
        }
        .buttonStyle(ToolbarIconButtonStyle())
        
        Button(action: { addingModel = true }) {
            Image(systemName: "plus")
        }
        .buttonStyle(ToolbarIconButtonStyle())
        
        Button(action: { showingDeleteTaskAlert = true}) {
            Image(systemName: "minus")
        }
        .disabled(selectedModel == nil)
        .alert("Confirm Deletion", isPresented: $showingDeleteTaskAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: removeModel)
        } message: {
            Text("Are you sure you want to delete model \(selectedModel?.name ?? "")?")
        }
        .buttonStyle(ToolbarIconButtonStyle())
        
        Spacer()

        if modelAPI.modelProvider == .huggingFace {
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        modelManager.selectedItem = .mlxView
                    }
                }) {
                    VStack(alignment: .center, spacing: 4) {
                        Image(systemName: "binoculars.circle")
                        Text("MLX Community")
                            .font(.system(size: 10))
                    }
                }
            }
            #if os(macOS)
            .frame(width: 90)
            #endif
            
            VStack(alignment: .center) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        modelManager.selectedItem = .hfModelListView
                    }
                }) {
                    VStack(alignment: .center, spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                        Text("Local Models")
                            .font(.system(size: 10))
                    }
                }
            }
            #if os(macOS)
            .frame(width: 90)
            #endif
        }

        Image(systemName: "circle.fill")
            .controlSize(.mini)
            .foregroundStyle(modelAPI.isAvailable ? .green : .red)
            .help("Model Status")
    }

    @ViewBuilder
    private var modelListHeaderContentCompact: some View {
        HStack {
            Text("Model List")
                .font(.subheadline.weight(.medium))

            Spacer()

            // Right-side controls (keep comfortable spacing)
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(modelAPI.isAvailable ? Color.green : Color.red)
                    .frame(width: 7, height: 7)

                // Refresh
                Button(action: updateModelStatus) {
                    Image(systemName: "arrow.trianglehead.clockwise.rotate.90")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                // Add model
                Button(action: { addingModel = true }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                if modelAPI.modelProvider == .huggingFace {
                    NavigationLink {
                        MLXCommunityView(modelAPI: ModelAPIDescriptor(from: modelAPI))
                    } label: {
                        Image(systemName: "binoculars.circle")
                            .font(.system(size: 16))
                    }
                    .foregroundStyle(.secondary)

                    NavigationLink {
                        HFModelListView(modelAPI: ModelAPIDescriptor(from: modelAPI))
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 16))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var localModelList: some View {
        if sortedModels.isEmpty {
            Text("No models added for this API.")
                .foregroundColor(.secondary)
                .padding()
                .frame(height: 200, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    ForEach(sortedModels) { localModel in
                        ModelRowView(
                            model: localModel,
                            isSelectting: selectedModel == localModel
                        ) { model in
                            selectedModel = model
                        }
                        .frame(height: 25)
                    }
                }
            }
        }
    }

    #if os(iOS)
    @ViewBuilder
    private var modelProviderIcon: some View {
        if let tab = matchedTab(modelProvider: modelAPI.modelProvider) {
            tab.icon
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
        } else {
            Image(systemName: "circle")
        }
    }

    @ViewBuilder
    private func modelRowLabel(_ model: Model) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.isAvailable ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(model.name)
                .font(.body)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    #endif
    
    private func updateModelStatus() {
        Task {
            errorShow = ""
            do {
                try await modelManager.updateModelStatus(for: modelAPI.name)
            } catch {
                errorShow = error.localizedDescription
            }
        }
    }
    
    private func removeModel() {
        guard let selectedModel = self.selectedModel else { return }
        modelManager.deleteModel(model: selectedModel)
    }
}

