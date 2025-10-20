import SwiftUI

struct HFModelDownloadView: View {
    @Environment(ModelManagerModel.self) var modelManager

    @State private var showingDeleteTaskAlert = false
    @State private var errorAlert: ErrorAlert?

    let modelAPI: ModelAPIDescriptor
    let hfModel: HFModel
    
    var body: some View {
        HStack(spacing: 10) {
            mainActionButton

            openDirectoryButton

            Button(action: { showingDeleteTaskAlert = true }) {
                Image(systemName: "trash")
                    .renderingMode(.original)
            }
            .alert("Confirm Deletion", isPresented: $showingDeleteTaskAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: deleteModel)
            } message: {
                Text("Are you sure you want to delete model \(hfModel.repoId)?")
            }
            .alert(item: $errorAlert) { alertInfo in
                Alert(
                    title: Text(alertInfo.title),
                    message: Text(alertInfo.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .buttonStyle(DarkenOnPressButtonCircleStyle())
    }

    @ViewBuilder
    private var mainActionButton: some View {
        switch hfModel.status {
        case .notDownloaded, .inComplete:
            Button(action: startDownload) {
                Image(systemName: "play.circle")
            }
            .foregroundColor(.orange)

        case .inDownloading:
            Button(action: pauseDownload, label: Image(systemName: "pause.circle"))
                .foregroundColor(.orange)

        case .inPause, .inPausing:
            Button(action: startDownload, label: Image(systemName: "play.circle"))
                .foregroundColor(.accentColor)
                .disabled(hfModel.status == .inPausing)

        case .needsUpdate:
            Button(action: startDownload, label: Image(systemName: "arrow.triangle.2.circlepath"))
                .foregroundColor(.purple)

        case .inCache:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)

        case .inDeleting:
            ProgressView()

        case .none:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private var openDirectoryButton: some View {
        Button(action: {
                openDir(at: hfModel.repoURL, in: modelAPI.cacheDir)
        }) {
            Image(systemName: "folder")
        }
        .controlSize(.small)
        .help("Open the directory where the model files are located")
        .disabled(hfModel.repoURL == nil)
        .buttonStyle(DarkenOnPressButtonCircleStyle())
    }
    
    private func startDownload() {
        Task {
            do {
                try await modelManager.hfModelListModel.startDownload(
                    modelAPI: modelAPI,
                    for: hfModel.repoId
                )
            } catch {
                let title = "Failed to start model download"
                let message = error.localizedDescription
                
                self.errorAlert = ErrorAlert(title: title, message: message)
            }
        }
    }
    
    private func pauseDownload() {
        Task {
            do {
                try await modelManager.hfModelListModel.pauseDownload(
                    modelAPI: modelAPI,
                    for: hfModel.repoId
                )
            } catch {
                let title = "Failed to stop model download"
                let message = error.localizedDescription
                
                self.errorAlert = ErrorAlert(title: title, message: message)
            }
        }
    }
    
    private func deleteModel() {
        Task {
            do {
                try await modelManager.hfModelListModel.deleteModel(
                    modelAPI: modelAPI,
                    for: hfModel.repoId
                )
            } catch {
                let title = "Failed to delete model"
                let message = error.localizedDescription
                
                self.errorAlert = ErrorAlert(title: title, message: message)
            }
        }
    }
    
    private func openDir(at urlToOpen: URL?, in urlInSecurity: URL?) {
        Task {
            do {
                guard let urlToOpen, let urlInSecurity else {
                    throw SimpleError(message: "Model directory is empty")
                }
                
                try FileManager.default.openDirectory(
                    at: urlToOpen,
                    in: urlInSecurity
                )
            } catch {
                let title = "Failed to open model directory"
                let message = error.localizedDescription
                
                self.errorAlert = ErrorAlert(title: title, message: message)
            }
        }
    }
}
