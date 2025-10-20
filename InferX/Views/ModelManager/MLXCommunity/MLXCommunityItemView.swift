import SwiftUI

struct HStackWidthPreferenceKey: @preconcurrency PreferenceKey {
    @MainActor static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MLXCommunityItemView: View {
    @Environment(ModelManagerModel.self) var modelManager

    let modelAPI: ModelAPIDescriptor
    
    @Binding var remoteHFModel: RemoteHFModel
    
    let animationSpeed: Double = 40.0

    @State private var isLoading = false
    @State private var textWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var isHoveringForItem = false
    @State private var hfModel: HFModel?
    @State private var errorAlert: ErrorAlert?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            modelItemView

            modelInfoView

            modelTagsView
        }
        .padding()
        .onHover { isHoveringForItem = $0 }
        .background(
            Rectangle()
                .fill(isHoveringForItem ? Color(.gray).opacity(0.2) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isHoveringForItem)
        .task {
            await fetchHFModelInfo()
        }
        .alert(item: $errorAlert) { alertInfo in
            Alert(
                title: Text(alertInfo.title),
                message: Text(alertInfo.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private var modelItemView: some View {
        HStack {
            Text(remoteHFModel.id)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(remoteHFModel.id)

            Spacer()

            Button(action: downloadNew) {
                if let hfModel {
                    Image(systemName: "arrowshape.down.circle.fill")
                        .foregroundColor(modelStatusColor(hfModel: hfModel))
                } else {
                    Image(systemName: "arrowshape.down.circle.fill")
                }
            }
            .padding(.horizontal, 10)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }

            Button(action: {
                if let url = URL(
                    string: "https://huggingface.co/\(remoteHFModel.id)")
                {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "safari")
            }
        }
        .buttonStyle(DarkenOnPressButtonCircleStyle())
    }
    
    @ViewBuilder
    private var modelInfoView: some View {
        HStack(spacing: 20) {
            Label("\(remoteHFModel.downloads)", systemImage: "arrow.down.circle")
                .font(.subheadline)

            Label("\(remoteHFModel.likes)", systemImage: "heart.fill")
                .font(.subheadline)
                .foregroundColor(.red.opacity(0.6))

            if let siblings = remoteHFModel.siblings, !siblings.isEmpty {
                Label("\(siblings.count)", systemImage: "menubar.dock.rectangle")
                    .font(.subheadline)
            }

            if let filesMeta = remoteHFModel.filesMeta, !filesMeta.isEmpty {
                Label(formatFileSize(getTotalSize(filesMeta)), systemImage: "internaldrive")
                        .font(.subheadline)
            }

            Text(getShortDate())
                .font(.caption)

            Spacer()

            if let pipelineTag = remoteHFModel.pipeline_tag {
                Text(pipelineTag)
                    .font(.subheadline)
                    .padding(4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }
    
    @ViewBuilder
    private var modelTagsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(remoteHFModel.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .fixedSize(horizontal:true, vertical: false)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: HStackWidthPreferenceKey.self, value: geometry.size.width)
                }
            }
            .offset(x: scrollOffset, y: 0)
            .onPreferenceChange(HStackWidthPreferenceKey.self) { width in
                textWidth = width
            }
        }
        .clipped()
        .onHover { hovered in
            if hovered {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func fetchHFModelInfo() async {
        do {
            guard let modelAPI = modelManager.activeModelAPI else {
                throw SimpleError(message: "There is no model API")
            }
            
            hfModel = try await modelManager.hfModelListModel.getHFModel(
                modelAPI: ModelAPIDescriptor(from: modelAPI),
                for: remoteHFModel.id
            )
            
            if remoteHFModel.filesMeta == nil {
                remoteHFModel.filesMeta = try await modelManager.hfModelListModel.getRemoteHFModel(
                    modelAPI: ModelAPIDescriptor(from: modelAPI),
                    for: remoteHFModel.id
                ).filesMeta
            }
        } catch {
            print("\(error.localizedDescription)")
        }
    }
    
    private func downloadNew() {
        Task {
            do {
                guard let modelAPI = modelManager.activeModelAPI else {
                    throw SimpleError(message: "There is no model API")
                }
                
                guard modelAPI.localModelsDir != nil else {
                    throw SimpleError(message: "Model cache dir is null, please select on")
                }
                
                if hfModel == nil {
                    isLoading = true
                    try await modelManager.hfModelListModel.downloadNew(
                        modelAPI: ModelAPIDescriptor(from: modelAPI),
                        for: remoteHFModel.id
                    )
                    isLoading = false
                }
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    modelManager.selectedItem = .hfModelListView
                }
            } catch {
                isLoading = false
                let title = "Failed to add new model download"
                let message = error.localizedDescription
                
                self.errorAlert = ErrorAlert(title: title, message: message)
            }
        }
    }
    
    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        withAnimation(.linear(duration: animationDuration()).repeatForever(autoreverses: false)) {
            scrollOffset = -textWidth
        }
    }

    func stopAnimation() {
        isAnimating = false
        withAnimation(.linear(duration: 0.2)) {
            scrollOffset = 0
        }
    }

    func animationDuration() -> Double {
        return Double(textWidth) / animationSpeed
    }

    private func getShortDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        let shortDateString = dateFormatter.string(from: remoteHFModel.createdAt)
        return shortDateString
    }

    private func modelStatusColor(hfModel: HFModel) -> Color {
        switch hfModel.status {
        case .notDownloaded, .inComplete:
            return .blue
        case .inDownloading, .inDeleting:
            return .orange
        case .inPause, .inPausing:
            return .accentColor
        case .needsUpdate:
            return .purple
        case .inCache:
            return .green
        case .none:
            return .gray
        }
    }

    private func getTotalSize(_ filesMeta: [String : HFFileMeta]) -> Int64 {
        return filesMeta.values.reduce(0) { total, fileMeta in
            total + (fileMeta.size ?? 0)
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}

