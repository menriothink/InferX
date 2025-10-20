//
//  ModelAPIAddSheetView.swift
//  InferX
//
//  Created by mingdw on 2025/10/2.
//

import SwiftUI
import SwiftData

struct ProviderPickerRowView: View {
    let provider: ModelProvider?
    var apiName: String?
    
    var body: some View {
        HStack {
            if let tab = matchedTab(modelProvider: provider) {
                tab.iconView()
                    .padding(.horizontal, 10)
                    .font(.footnote)
            }
            
            Text(apiName ?? provider?.rawValue ?? "")
        }
    }
}

struct ModelAPIAddSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsModel.self) private var settingsModel
    @Environment(ModelManagerModel.self) var modelManager

    @State private var apiName = ""
    @State private var modelProvider = ModelProvider.huggingFace
    @State private var apiKey: String = ""
    @State private var endPoint: String = ""
    @State private var directoryPathForHFModel: String = ""
    @State private var directoryPathErrorAlert: String = ""
    @State private var localModelsDir: URL?
    @State private var errorAlert: String = ""

    var onCompletion: ((_ api: ModelAPI?) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Form {
                Picker("Provider", selection: $modelProvider) {
                    ForEach(ModelProvider.allCases.filter { $0 != .none }, id: \.self) { provider in
                        ProviderPickerRowView(provider: provider).tag(provider)
                    }
                }
                .frame(minWidth: 200)
                
                TextField("API Name", text: $apiName)
                
                TextField("API Endpoint URL", text: $endPoint)
                
                SecureField("API Key", text: $apiKey)
                
                if modelProvider == .huggingFace {
                    HStack {
                        TextField("Local Model Directory", text: $directoryPathForHFModel)
                            .onSubmit {
                                checkDirForHFModel()
                            }
                        
                        Button(action: {
                            directoryPathForHFModel = FileManager.default.openDirectorySelectionPanel(
                                selectedModelDir: URL(fileURLWithPath: directoryPathForHFModel)
                            )?.path ?? ""
                            
                            checkDirForHFModel()
                        }) {
                            Image(systemName: "folder.badge.gearshape")
                        }
                    }
                }
                
                VStack {
                    if modelProvider == .huggingFace && !directoryPathErrorAlert.isEmpty {
                        Text(directoryPathErrorAlert)
                    } else if !errorAlert.isEmpty {
                        Text(errorAlert)
                    }
                }
                .font(.headline)
                .foregroundStyle(.red)
                .frame(width: 400)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.bottom, 50)
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            
            footerButtons
        }
        .frame(width: 480, height: 400)
        .task(id: modelProvider) {
            apiName = modelManager.generateUniqueDefaultAPIName(for: modelProvider)
            endPoint = modelProvider.endPoint
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("Configure Model Provider")
                .font(.title2.bold())
            Spacer()
            Button(action: cancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding()
        .background(.bar)
    }

    @ViewBuilder
    private var footerButtons: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel, action: cancel)
            Button("Save", action: save)
                .keyboardShortcut(.defaultAction)
                .disabled(
                    modelProvider == .none ||
                    endPoint.trimmingCharacters(in: .whitespaces).isEmpty ||
                    modelProvider == .huggingFace && directoryPathForHFModel.isEmpty ||
                    modelProvider == .huggingFace && !directoryPathErrorAlert.isEmpty
                )
        }
        .padding()
    }

    private func save() {
        if modelProvider == .huggingFace {
            checkDirForHFModel()
            if !directoryPathErrorAlert.isEmpty {
                return
            }
        }
                
        var modelAPI: ModelAPI?
        do {
            modelAPI = try modelManager.createModelAPI(
                name: apiName,
                modelProvider: modelProvider,
                endPoint: endPoint,
                apiKey: apiKey
            )
            
            guard let modelAPI = modelAPI else {
                throw SimpleError(message: "Error: Failed to create model API \(apiName)")
            }
            
            if modelProvider == .huggingFace {
                try handleDirectorySelection(modelAPI: modelAPI)
            }
            
            settingsModel.selectedItem = .modelAPIManager
            modelManager.selectedItem = .modelAPIDetail
            modelManager.activeModelAPI = modelAPI
            
            Task {
                do {
                    try await modelManager.updateModelStatus(for: apiName)
                } catch {
                    print(error)
                }
            }
            
            onCompletion?(modelAPI)
            dismiss()
        } catch(let error) {
            if let modelAPI = modelAPI {
                modelManager.deleteModelAPI(modelAPI: modelAPI)
            }
            
            errorAlert = "Save failed, " + error.localizedDescription
            print(errorAlert)
            onCompletion?(nil)
        }
    }

    private func cancel() {
        onCompletion?(nil)
        dismiss()
    }
    
    private func checkDirForHFModel() {
        errorAlert = ""
        directoryPathErrorAlert = ""
        
        let trimmedPath = directoryPathForHFModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            directoryPathErrorAlert = "Error: Local model directory cannot be empty"
            return
        }
                
        localModelsDir = URL(fileURLWithPath: directoryPathForHFModel, isDirectory: true)
        
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: localModelsDir?.path ?? "",
            isDirectory: &isDirectory
        ) else {
            directoryPathErrorAlert = "Error: Path \(localModelsDir?.path ?? "") does not exist"
            return
        }
        
        guard isDirectory.boolValue else {
            directoryPathErrorAlert = "Error: \(localModelsDir?.path ?? "") is a file, not a directory"
            return
        }
        
        print("\(String(describing: localModelsDir?.standardized))")
        for modelAPI in modelManager.modelAPIs {
            print("\(String(describing: modelAPI.localModelsDir?.standardized))")
        }
        
        if let modelAPI = modelManager.modelAPIs.first(
            where: { $0.localModelsDir?.standardized  == localModelsDir?.standardized  }
        ) {
            directoryPathErrorAlert = "Error: Local model directory is already occupied by model API \(modelAPI.name), please reselect"
            print(directoryPathErrorAlert)
            return
        }
    }
    
    private func handleDirectorySelection(modelAPI: ModelAPI) throws {
        modelAPI.localModelsDir = localModelsDir
        
        guard modelAPI.localModelsDir != nil else {
            throw SimpleError(message: "Error: Model local storage directory may have insufficient permissions, please reselect")
        }
                
        Task {
            do {
                let modelAPI = ModelAPIDescriptor(from: modelAPI)
                try await modelManager.hfModelListModel.updateHFModelsFromCache(modelAPI: modelAPI)
            } catch {
                let errorShow = "Failed to find model in current folder: \(error.localizedDescription)"
                print(errorShow)
            }
        }
    }
}

