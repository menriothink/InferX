//
//  ModelAddSheetView.swift
//  InferX
//
//  Created by mingdw on 2025/10/2.
//

import SwiftUI
import SwiftData

struct ModelAddSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsModel.self) private var settingsModel
    @Environment(ModelManagerModel.self) private var modelManager

    var inputApiName: String?
    var onModelCreated: ((Model) -> Void)?

    @State private var selectedAPIName: String?
    @State private var selectedModelNames = Set<String>()
    @State private var isFetchingModels = false
    @State private var fetchError: String?
    @State private var apiToConfigure: Bool = false
    @State private var errorAlert: String = ""

    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Form {
                Picker("Model API", selection: $selectedAPIName) {
                    Text("Please select a Model API...").tag(nil as String?)
                    ForEach(modelManager.modelAPIs) { api in
                        ProviderPickerRowView(
                            provider: api.modelProvider,
                            apiName: api.name
                        ).tag(api.name as String?)
                    }
                }
                .onChange(of: selectedAPIName, handleAPISelectionChange)
                .disabled(inputApiName != nil)
                
                Section("Available Models") {
                    dynamicContentSection
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            
            Spacer()
            
            VStack {
                if modelManager.modelAPIs.isEmpty {
                    Text("No Model APIs available, please create one.")
                        .font(.headline)
                } else if modelManager.localModels.isEmpty {
                    Text("No models available, please add one.")
                        .foregroundStyle(.yellow)
                } else if !errorAlert.isEmpty {
                    Text(errorAlert)
                        .foregroundStyle(.red)
                }
            }
            .font(.headline)
            .frame(width: 400)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.bottom, 50)

            Spacer()
            
            footerButtons
        }
        .frame(width: 480, height: 400)
        .sheet(isPresented: $apiToConfigure) {
            ModelAPIAddSheetView { api in
                if let api = api {
                    selectedAPIName = api.name
                }
            }
        }
        .onAppear {
            if let inputApiName = self.inputApiName {
                selectedAPIName = inputApiName
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("Add New Model")
                .font(.title2.bold())
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding().background(.bar)
    }

    @ViewBuilder
    private var dynamicContentSection: some View {
        if isFetchingModels {
            HStack {
                ProgressView()
                Text("Fetching available models...").foregroundStyle(.secondary)
            }
            .padding()
        } else if let error = fetchError {
            Text("Error: \(error)")
                .foregroundStyle(.red)
                .padding()
        } else if let selectedAPI = modelManager.modelAPIs.first(where: { $0.name == selectedAPIName }) {
            if let remoteModels = modelManager.remoteModels[selectedAPI.name] {
                let availableRemoteModels = remoteModels.filter { model in
                    !(modelManager.localModels[selectedAPI.name]?.contains(where: { $0.name == model.name }) ?? false)
                }
                
                if availableRemoteModels.isEmpty {
                    Text("All available models have been added.")
                        .foregroundStyle(.secondary)
                } else {
                    List(selection: $selectedModelNames) {
                        ForEach(availableRemoteModels.sorted { $0.name < $1.name }) { model in
                            Text(model.name).tag(model.name)
                        }
                    }
                    .listStyle(.inset)
                }
            } else {
                Text("Unknown error, no available models!")
                    .foregroundStyle(.red)
                    .font(.subheadline)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private var footerButtons: some View {
        HStack {
            Button("Create New Model API...") {
                apiToConfigure = true
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
            Button("Add Models", action: addSelectedModel)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedModelNames.isEmpty)
        }
        .padding()
    }
    
    private func handleAPISelectionChange(oldValue: String?, newValue: String?) {
        selectedModelNames.removeAll()
        fetchError = nil
        isFetchingModels = false
        
        guard let selectedAPI = modelManager.modelAPIs.first(
            where: { $0.name == newValue }
        ) else { return }
        
        if modelManager.remoteModels[selectedAPI.name]?.isEmpty ?? true {
            Task {
                await updateModels(for: selectedAPI)
            }
        }
    }

    private func updateModels(for modelAPI: ModelAPI) async {
        isFetchingModels = true
        fetchError = nil
        
        do {
            try await modelManager.updateModelStatus(for: modelAPI.name)
        } catch(let error) {
            fetchError = error.localizedDescription
        }
        
        isFetchingModels = false
    }
    
    private func addSelectedModel() {
        errorAlert = ""
        
        var modelsAdded: [Model] = []
        do {
            guard !selectedModelNames.isEmpty,
                  let apiName = selectedAPIName,
                  let selectedAPI = modelManager.modelAPIs.first(where: { $0.name == apiName })
            else {
                throw SimpleError(message: "Error: Incomplete data to add models.")
            }
            
            for modelName in selectedModelNames.sorted() {
                let newModel = try modelManager.createModel(
                    name: modelName,
                    modelAPI: selectedAPI
                )
                modelsAdded.append(newModel)
            }
            
            if let lastModel = modelsAdded.last {
                onModelCreated?(lastModel)
            }
            dismiss()
        } catch(let error) {
            for newModel in modelsAdded {
                modelManager.deleteModel(model: newModel)
            }
            
            errorAlert = "Failed to save, " + error.localizedDescription
            print(errorAlert)
        }
    }
}
