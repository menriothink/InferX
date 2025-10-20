import SwiftUI

struct HFModelListView: View {
    @Environment(ModelManagerModel.self) var modelManager

    let modelAPI: ModelAPIDescriptor
    
    @State private var showingDeleteAlert = false
    @State private var directoryPathForTextField: String = ""
    @State private var errorShow = ""
    
    var body: some View {
        VStack(alignment: .leading) {

            modelHeaderView
            
            Text(errorShow)
                .foregroundStyle(.red)

            modelListView

            Spacer()
        }
        .foregroundColor(Color(.controlTextColor))
        .accentColor(Color(.controlAccentColor))
        .overlay(alignment: .topLeading) {
            Button(action: {
                withAnimation(.easeInOut(duration: 1.0)) {
                        modelManager.selectedItem = .modelAPIDetail
                }
            }) {
                Image(systemName: "arrow.left")
            }
            .font(.title2)
            .padding(.top, -20)
        }
        .task {
            directoryPathForTextField = modelManager.activeModelAPI?.localModelsDir?.path ?? ""
            await updateHFModels()
        }
        .alert("Confirm Deletion", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteModel)
        } message: {
            Text("Are you sure you want to delete all models?")
        }
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
        .buttonStyle(DarkenOnPressButtonCircleStyle())
    }
    
    @ViewBuilder
    private var modelHeaderView: some View {
        Text("Local Model List").font(.headline)
            .padding(.top, 20)

        HStack {
            TextField("Local Model Directory", text: $directoryPathForTextField)
                .textFieldStyle(.plain)
                .padding(5)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.gray).opacity(0.1))
                )
                .onSubmit {
                    handleDirectorySelection(URL(fileURLWithPath: directoryPathForTextField))
                }

            Button(action: {
                if let url = FileManager.default.openDirectorySelectionPanel(
                    selectedModelDir: URL(fileURLWithPath: directoryPathForTextField)
                ) {
                    handleDirectorySelection(url)
                }
            }) {
                Image(systemName: "folder.badge.gearshape")
            }

            Button(action: { showingDeleteAlert = true }) {
                Image(systemName: "trash")
            }

            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    modelManager.selectedItem = .mlxView
                }
            }) {
                Image(systemName: "plus")
            }
        }
        .disabled(modelManager.hfModelListModel.isUpdatting)
    }
    
    @ViewBuilder
    private var modelListView: some View {
        if modelManager.hfModelListModel.isUpdatting {
            ProgressView()
                .frame(height: 50)
        } else if let hfModels = modelManager.hfModelListModel.hfModels[modelAPI.name], !hfModels.isEmpty {
            ScrollView {
                LazyVStack {
                    ForEach(hfModels) { hfModel in
                        HFModelItemView(modelAPI: modelAPI, hfModel: hfModel)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor).opacity(0.4))
            )
        } else {
            Text("No available models found in the current directory. Please add and download from the model community page.")
                .padding(20)
        }
    }

    private func updateHFModels() async {
        modelManager.hfModelListModel.isUpdatting = true
        do {
            try await modelManager.hfModelListModel.updateHFModels(modelAPI: modelAPI)
            errorShow = ""
        } catch {
            errorShow = "Failed to find model in current folder: \(error.localizedDescription)"
        }
        modelManager.hfModelListModel.isUpdatting = false
    }

    private func handleDirectorySelection(_ url: URL?) {
        guard let localModelsDir = url else {
            errorShow = "Invalid folder, please reselect"
            return
        }
        
        let trimmedPath = localModelsDir.path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            errorShow = "Model folder cannot be empty"
            return
        }
                
        if localModelsDir != modelManager.activeModelAPI?.localModelsDir {
            if let modelAPI = modelManager.modelAPIs.first(where: { $0.localModelsDir == localModelsDir }) {
                errorShow = "Model folder is already occupied by \(modelAPI.name), please reselect"
                return
            }
            
            modelManager.activeModelAPI?.localModelsDir = localModelsDir
            
            guard let modelAPI = modelManager.activeModelAPI else {
                errorShow = "current model API is invalid"
                return
            }
            
            guard modelManager.activeModelAPI?.localModelsDir != nil else {
                errorShow = "Model folder may have insufficient permissions, please reselect"
                return
            }
            
            directoryPathForTextField = localModelsDir.path
            print("select HF model catch path: \(String(describing: modelManager.activeModelAPI?.localModelsDir))")
            
            Task {
                modelManager.hfModelListModel.isUpdatting = true
                do {
                    let modelAPI = ModelAPIDescriptor(from: modelAPI)
                    try await modelManager.hfModelListModel.updateHFModelsFromCache(modelAPI: modelAPI)
                    errorShow = ""
                } catch {
                    errorShow = "Failed to find model in current folder: \(error.localizedDescription)"
                }
                modelManager.hfModelListModel.isUpdatting = false
            }
        }
    }
    
    private func deleteModel() {
        Task {
            do {
                try await modelManager.hfModelListModel.clearCache(modelAPI: modelAPI)
            } catch {
                errorShow = "Failed to delete model: \(error.localizedDescription)"
            }
        }
    }
}
