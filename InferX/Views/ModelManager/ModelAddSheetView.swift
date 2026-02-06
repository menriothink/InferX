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
        Group {
            #if os(iOS)
            iosContent
            #else
            macContent
            #endif
        }
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

    #if os(iOS)
    private var iosContent: some View {
        NavigationStack {
            List {
                Section("Model API") {
                    modelAPIMenuIOS
                }

                Section("Available Models") {
                    availableModelsContentIOS
                }

                if modelManager.modelAPIs.isEmpty || modelManager.localModels.isEmpty || !errorAlert.isEmpty {
                    Section {
                        statusMessageView
                    }
                }

                Section {
                    Button {
                        apiToConfigure = true
                    } label: {
                        Text("Create New Model API...")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add New Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Models", action: addSelectedModel)
                        .disabled(selectedModelNames.isEmpty)
                }
            }
        }
    }
    #endif

    #if os(iOS)
    private var modelAPIMenuIOS: some View {
        Menu {
            ForEach(modelManager.modelAPIs) { api in
                Button {
                    selectedAPIName = api.name
                } label: {
                    ProviderPickerRowView(
                        provider: api.modelProvider,
                        apiName: api.name
                    )
                }
            }
        } label: {
            HStack {
                if let selectedAPI = modelManager.modelAPIs.first(where: { $0.name == selectedAPIName }) {
                    ProviderPickerRowView(
                        provider: selectedAPI.modelProvider,
                        apiName: selectedAPI.name
                    )
                    .foregroundStyle(.primary)
                } else {
                    Text("Please select a Model API...")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(inputApiName != nil)
        .onChange(of: selectedAPIName, handleAPISelectionChange)
    }
    #endif

    private var macContent: some View {
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
            }
            .formStyle(.grouped)
            .frame(height: 60)

            VStack(alignment: .leading, spacing: 8) {
                Text("Available Models")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 20)

                dynamicContentSection
                    .frame(height: 200)
                    .padding(.horizontal)
            }

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
            .padding(.vertical, 8)

            Spacer()

            footerButtons
        }
        .padding(10)
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
            VStack {
                ProgressView()
                Text("Fetching available models...").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = fetchError {
            VStack {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let selectedAPI = modelManager.modelAPIs.first(where: { $0.name == selectedAPIName }) {
            if let remoteModels = modelManager.remoteModels[selectedAPI.name] {
                let availableRemoteModels = remoteModels.filter { model in
                    !(modelManager.localModels[selectedAPI.name]?.contains(where: { $0.name == model.name }) ?? false)
                }

                if availableRemoteModels.isEmpty {
                    VStack {
                        Text("All available models have been added.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        HStack {
                            Button(action: { selectAll(availableRemoteModels) }) {
                                Text("Select All")
                            }
                            Button(action: deselectAll) {
                                Text("Deselect All")
                            }
                            Spacer()
                        }
                        .frame(height: 20)
                        
                        List {
                            ForEach(availableRemoteModels.sorted { $0.name < $1.name }) { model in
                                Toggle(isOn: self.makeBinding(for: model.name)) {
                                    HStack {
                                        Text(model.name)
                                        Spacer()
                                    }
                                    .clipShape(.rect(cornerRadius: 12))
                                    .contentShape(Rectangle())
                                }
                                #if os(macOS)
                                .toggleStyle(.checkbox)
                                #endif
                                .padding(.horizontal, 4)
                            }
                        }
                        #if os(macOS)
                        .listStyle(.bordered(alternatesRowBackgrounds: true))
                        #endif
                        .scrollContentBackground(.visible)
                    }
                }
            } else {
                VStack {
                    Text("Unknown error, no available models!")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            VStack {
                Text("Please select a Model API above")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    #if os(iOS)
    @ViewBuilder
    private var availableModelsContentIOS: some View {
        if isFetchingModels {
            HStack(spacing: 8) {
                ProgressView()
                Text("Fetching available models...")
                    .foregroundStyle(.secondary)
            }
        } else if let error = fetchError {
            Text("Error: \(error)")
                .foregroundStyle(.red)
        } else if let selectedAPI = modelManager.modelAPIs.first(where: { $0.name == selectedAPIName }) {
            if let remoteModels = modelManager.remoteModels[selectedAPI.name] {
                let availableRemoteModels = remoteModels.filter { model in
                    !(modelManager.localModels[selectedAPI.name]?.contains(where: { $0.name == model.name }) ?? false)
                }

                if availableRemoteModels.isEmpty {
                    Text("All available models have been added.")
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 12) {
                        Button(action: { selectAll(availableRemoteModels) }) {
                            Text("Select All")
                        }
                            .buttonStyle(.plain)
                        Button(action: deselectAll) {
                            Text("Deselect All")
                        }
                            .buttonStyle(.plain)
                        Spacer()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    ForEach(availableRemoteModels.sorted { $0.name < $1.name }) { model in
                        Toggle(isOn: self.makeBinding(for: model.name)) {
                            Text(model.name)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                Text("Unknown error, no available models!")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
        } else {
            Text("Please select a Model API above")
                .foregroundStyle(.secondary)
        }
    }
    #endif

    @ViewBuilder
    private var footerButtons: some View {
        HStack {
            Button {
                apiToConfigure = true
            } label: {
                Text("Create New Model API...")
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
            Button("Add Models", action: addSelectedModel)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedModelNames.isEmpty)
        }
        .padding()
    }

    @ViewBuilder
    private var statusMessageView: some View {
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
    
    private func makeBinding(for modelName: String) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                self.selectedModelNames.contains(modelName)
            },
            set: { isSelected in
                if isSelected {
                    self.selectedModelNames.insert(modelName)
                } else {
                    self.selectedModelNames.remove(modelName)
                }
            }
        )
    }
    
    private func selectAll(_ availableRemoteModels: [RemoteModel]) {
        selectedModelNames = Set(availableRemoteModels.map { $0.name })
    }

    private func deselectAll() {
        selectedModelNames.removeAll()
    }
}
