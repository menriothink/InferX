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
    
    var body: some View {
        Form {
            Section(header: Text("Model API Settings").font(.headline)) {
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
                .disableAutocorrection(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Section(header: Text("Model Settings").font(.headline)) {
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
            }
        }
        .foregroundColor(.primary)
        .accentColor(.primary)
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .sheet(isPresented: $addingModel) {
            ModelAddSheetView(inputApiName: modelAPI.name)
        }

    }
        
    private var modelListHeader: some View {
        HStack(spacing: 5) {
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
                        }
                    }
                }
                .frame(width: 80)
                
                VStack(alignment: .center) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            modelManager.selectedItem = .hfModelListView
                        }
                    }) {
                        VStack(alignment: .center, spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text("Local Models")
                        }
                    }
                }
                .frame(width: 80)
                
            }

            Image(systemName: "circle.fill")
                .controlSize(.mini)
                .foregroundStyle(modelAPI.isAvailable ? .green : .red)
                .help("Model Status")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }
    
    @ViewBuilder
    private var localModelList: some View {
        let models = modelManager.localModels[modelAPI.name] ?? []
        if models.isEmpty {
            Text("No models added for this API.")
                .foregroundColor(.secondary)
                .padding()
                .frame(height: 200, alignment: .center)
        } else {
            let sortedModels = models.sorted { $0.createdAt > $1.createdAt }
            
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
            //.frame(height: min(CGFloat(models.count) * 35, 200))
        }
    }
    
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

