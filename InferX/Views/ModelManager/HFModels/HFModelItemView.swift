import SwiftUI

struct HFModelItemView: View {
    @Environment(ModelManagerModel.self) var modelManager

    let modelAPI: ModelAPIDescriptor
    let hfModel: HFModel

    @State private var isHovering = false
    @State private var breathingOpacity: Double = 0.2
    @State private var textWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var showPopover = false

    let animationSpeed: Double = 40.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            modelItemView

            modelFileListView

            modelProgressView
        }
        .padding()
        .onHover { isHovering = $0 }
        .background(Rectangle().fill(
                hfModel.status == .inDownloading
                    ? Color(.gray).opacity(breathingOpacity)
                    : (isHovering ? Color(.gray).opacity(0.2) : Color.clear)
            )
        )
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onAppear {
            if hfModel.status == .inDownloading {
                withAnimation(Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)) { breathingOpacity = 0.05 }
            }
        }
        .onDisappear { breathingOpacity = 0.0 }
    }

    @ViewBuilder
    private var modelItemView: some View {
        HStack {
            Text(hfModel.repoId)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(hfModel.repoId)

            Spacer()

            Text(hfModel.createdAt.toFormatted(style: .short))
                .lineLimit(1)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let totalSize = hfModel.totalSize {
                Label(FileSizeFormatter.string(from: Int64(totalSize)),
                systemImage: "internaldrive").font(.subheadline)
            }

            HFModelDownloadView(modelAPI: modelAPI, hfModel: hfModel)
        }
    }

    @ViewBuilder
    private var modelFileListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(getExpectedFilesForRepo(), id: \.self) { file in
                    Text(file)
                        .foregroundStyle(isCompleted(file: file) ? Color.primary : Color.secondary)
                        .cornerRadius(8)
                        .padding(.trailing, -2)

                    if let progress = hfModel.progress {
                       if let fileProgress = progress.individualProgresses[file] {
                           let completedBytes = fileProgress.progress?.completedUnitCount ?? 0
                           let totalBytes = fileProgress.progress?.totalUnitCount ?? 0
                           let completedString = FileSizeFormatter.string(from: completedBytes)
                           let totalString = FileSizeFormatter.string(from: totalBytes)
                           Text("\(completedString) / \(totalString)")
                               .monospacedDigit()
                               .foregroundStyle(isCompleted(file: file) ? Color.primary : Color.secondary)
                               .padding(.trailing, 10)
                       }
                   }
                }
                .font(.caption)
            }
            .padding(.vertical, 1)
            .fixedSize(horizontal:true, vertical: false)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: HStackWidthPreferenceKey.self, value: geometry.size.width)
                }
            }
            .offset(x: scrollOffset, y: 0)
            .onPreferenceChange(HStackWidthPreferenceKey.self) { width in
                Task { @MainActor in
                    if width.isFinite && width > 0 {
                        textWidth = width
                    }
                }
            }
        }
        .frame(height: 30)
        .onHover { hovered in
            if hovered {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }

    @ViewBuilder
    private var modelProgressView: some View {
        if let progress = hfModel.progress {
            HStack(spacing: 8) {
                let fractionCompleted = getSafeFractionCompleted(
                    progress: progress.totalProgress
                )

                ProgressView(value: fractionCompleted)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.green)

                let completedUnitCount = progress.totalProgress.completedUnitCount
                let totalUnitCount = progress.totalProgress.totalUnitCount

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showPopover.toggle()
                    }
                }) {
                    HStack(spacing: 2) {
                        Text("\(completedUnitCount)/\(totalUnitCount)")
                            .fontWeight(.medium)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .rotationEffect(.degrees(showPopover ? 90 : 0))
                            .opacity(0.8)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Click to view detailed download progress")

                Text(String(format: "%.0f%%", fractionCompleted * 100))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 35, alignment: .trailing)
            }
            .frame(height: 10)

            if showPopover {
                downloadStatusView
                    .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var downloadStatusView: some View {
        ScrollView {
            VStack {
                ForEach(getExpectedFilesForRepo(), id: \.self) { file in
                    if let progress = hfModel.progress {
                        HStack {
                            Text(file)
                                .frame(width: 180, alignment: .leading)

                            let fileProgress = progress.individualProgresses[file] ?? IndividualProgress()
                            let fractionCompleted = getSafeFractionCompleted(
                                progress: fileProgress.progress
                            )
                            ProgressView(value: fractionCompleted)
                                .progressViewStyle(LinearProgressViewStyle())
                                .tint(.green)
                                .frame(maxWidth: .infinity)

                            Spacer()

                            Text(String(format: "%.0f%%", fractionCompleted * 100))
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 39, alignment: .trailing)

                            let completedBytes = fileProgress.progress?.completedUnitCount ?? 0
                            let totalBytes = fileProgress.progress?.totalUnitCount ?? 0
                            let completedString = FileSizeFormatter.string(from: completedBytes)
                            let totalString = FileSizeFormatter.string(from: totalBytes)
                            Text("\(completedString) / \(totalString)")
                                .frame(width: 120, alignment: .trailing)
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    private func getExpectedFilesForRepo() -> [String] {
        var files: [String] = []

        if let expectedFiles = hfModel.expectedFiles {
            files = expectedFiles
        } else if let progress = hfModel.progress {
            files = progress.individualProgresses.values.map { $0.downloadingFileName }
        }

        return files.sorted()
    }

    private func isCompleted(file: String) -> Bool {
        if let progress = hfModel.progress {
            if let fileProgress = progress.individualProgresses[file] {
                let completedUnits = fileProgress.progress?.completedUnitCount ?? 0
                let totalUnits = fileProgress.progress?.totalUnitCount ?? 0
                return completedUnits >= totalUnits && totalUnits != 0
            }
        } else if case .inCache = hfModel.status {
            return true
        } else if case .inComplete(let missingFiles) = hfModel.status {
            return !missingFiles.contains(file)
        }
        return false
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
        if textWidth > 0 && animationSpeed > 0 {
            return Double(textWidth) / animationSpeed
        }
        return .greatestFiniteMagnitude
    }

    private func getSafeFractionCompleted(progress: Progress?) -> Double {
        if let progress, progress.totalUnitCount > 0 {
            return min(1.0, max(0.0, progress.fractionCompleted))
        } else {
            return 0.0
        }
    }
}

@MainActor
struct FileSizeFormatter {

    static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()

        formatter.allowedUnits = [
            .useBytes,
            .useKB,
            .useMB,
            .useGB,
            .useTB
        ]

        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        formatter.zeroPadsFractionDigits = false
        //formatter.maximumFractionDigits = 1
        return formatter
    }()

    static func string(from byteCount: Int64) -> String {
        let count = byteCount < 0 ? 0 : byteCount
        return formatter.string(fromByteCount: count)
    }
}
