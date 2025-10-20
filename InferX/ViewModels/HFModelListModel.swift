/**********************************************************
~/.cache/huggingface/hub/
├── .locks/              # Lock files directory
├── blobs/               # Data entity (Blob) storage directory
├── models--gpt2/        # Repository storage folder (example)
│   ├── blobs/
│   ├── refs/
│   └── snapshots/
└── datasets--squad/     # Dataset storage folder (example)
    ├── blobs/
    ├── refs/
    └── snapshots/
**********************************************************/
import SwiftUI
import Foundation

@MainActor
@Observable
final class HFModel: Identifiable {
    enum Status: Equatable {
        case inCache
        case inComplete(missingFiles: [String])
        case needsUpdate
        case notDownloaded
        case inDownloading
        case inPause
        case inPausing
        case inDeleting
        case none

        var raw: String {
            switch self {
            case .inCache:
                return "in cache"
            case .inComplete(let missingFiles):
                return "in complete, missing files: \(missingFiles)"
            case .needsUpdate:
                return "in needs update"
            case .notDownloaded:
                return "in not download"
            case .inDownloading:
                return "in downloading"
            case .inPause:
                return "in pause"
            case .inPausing:
                return "in pausing"
            case .inDeleting:
                return "in deleting"
            case .none:
                return "in none"
            }
        }
    }

    var repoId: String
    var repoURL: URL?
    var status: Status
    var expectedFiles: [String]?
    var createdAt: Date
    var lastCommit: String?
    var totalSize: Int?
    var progress: ExtendedProgresss?
    var downloader: SnapshotDownloader?
    var downloadTask: Task<Void, Never>?

    init(
        repoId: String,
        repoURL: URL? = nil,
        status: Status,
        expectedFiles: [String]? = nil,
        createdAt: Date,
        lastCommit: String? = nil,
        totalSize: Int? = nil,
        progress: ExtendedProgresss? = nil,
        downloader: SnapshotDownloader? = nil,
        downloadTask: Task<Void, Never>? = nil
    ) {
        self.repoId = repoId
        self.repoURL = repoURL
        self.status = status
        self.expectedFiles = expectedFiles
        self.createdAt = createdAt
        self.lastCommit = lastCommit
        self.totalSize = totalSize
        self.progress = progress
        self.downloader = downloader
        self.downloadTask = downloadTask
    }
}

@MainActor
@Observable
final class HFModelListModel {

    var hfModels: [String: [HFModel]] = [:]

    var isUpdatting: Bool = false

    private var hfService = HuggingFaceService.shared

    func updateHFModelsFromCache(modelAPI: ModelAPIDescriptor) async throws {
        let localHFModels = try await hfService.updateLocalHFModelsFromCache(modelAPI: modelAPI)

        self.hfModels[modelAPI.name] = updateHFModels(
            from: localHFModels,
            for: self.hfModels[modelAPI.name] ?? []
        )
    }

    func updateHFModels(modelAPI: ModelAPIDescriptor) async throws {
        let localHFModels = try await hfService.getLocalHFModels(modelAPI: modelAPI)

        self.hfModels[modelAPI.name] = updateHFModels(
            from: localHFModels,
            for: self.hfModels[modelAPI.name] ?? []
        )
    }

    func getHFModel(
        modelAPI: ModelAPIDescriptor,
        for repoId: String
    ) async throws -> HFModel? {
        return self.hfModels[modelAPI.name]?.first(where: { $0.repoId == repoId })
    }

    func getRemoteHFModel(
        modelAPI: ModelAPIDescriptor,
        for repoId: String
    ) async throws -> RemoteHFModel {
        return try await hfService.getRemoteHFModel(modelAPI: modelAPI, repoId: repoId)
    }

    func getRemoteHFModels(
        modelAPI: ModelAPIDescriptor,
        loadMore: Bool = false,
        searchQuery: String? = nil,
        sortValue: String = "",
        direction: String = "-1"
    ) async throws -> [RemoteHFModel] {
        return try await hfService.getRemoteHFModels(
            modelAPI: modelAPI,
            loadMore: loadMore,
            search: searchQuery,
            sortValue: sortValue,
            direction: direction
        )
    }

    func downloadNew(modelAPI: ModelAPIDescriptor, for repoId: String) async throws {
        var hfModels = self.hfModels[modelAPI.name] ?? []

        guard !hfModels.contains(where: { $0.repoId == repoId }) else {
            throw SimpleError(message: "Error: Already in model list, repoId '\(repoId)'")
        }

        let remoteHFModel = try await hfService.getRemoteHFModel(modelAPI: modelAPI, repoId: repoId)
        let hFModel = HFModel(
            repoId: repoId,
            status: .notDownloaded,
            expectedFiles: remoteHFModel.siblings?.map { $0.rfilename },
            createdAt: .now
        )

        hfModels.append(hFModel)
        hfModels.sort { $0.createdAt > $1.createdAt }
        self.hfModels[modelAPI.name] = hfModels
        try await startDownload(modelAPI: modelAPI, for: repoId)
    }

    func startDownload(modelAPI: ModelAPIDescriptor, for repoId: String) async throws {
        let hfModels = self.hfModels[modelAPI.name] ?? []

        guard let hfModel = hfModels.first(where: { $0.repoId == repoId }) else {
            throw SimpleError(message: "Error: HF Models not found repoId '\(repoId)'")
        }

        guard hfModel.status != .inDownloading,
              hfModel.status != .inDeleting,
              hfModel.status != .inPausing else {
            throw SimpleError(message: "Error: modle is \(hfModel.status.raw) before downloading, repoId '\(repoId)'")
        }

        hfModel.status = .inDownloading

        if hfModel.downloader == nil {
            let progressHandler: @Sendable (ExtendedProgresss) -> Void = { progress in
                Task {
                    await MainActor.run {
                        if let model = hfModels.first(where: { $0.repoId == repoId }) {
                            model.progress = progress
                        }
                    }
                }
            }

            hfModel.downloader = await self.hfService.snapshotDownloader(
                modelAPI: modelAPI,
                repoId: repoId,
                repoType: .model,
                progressHandler: progressHandler
            )
        }

        guard let downloaderToRun = hfModel.downloader else {
            throw SimpleError(message: "Error: Cannot initialize download task repoId '\(repoId)'")
        }

        hfModel.downloadTask = Task {
            guard let cacheDir = modelAPI.cacheDir else {
                return
            }

            guard let cacheDir = FileManager.default.securityAccessFile(url: cacheDir) else {
                print("❌ Unable to begin secure access to source URL.")
                return
            }


            defer {
                cacheDir.stopAccessingSecurityScopedResource()
            }

            do {
                let snapshot = try await downloaderToRun.download()
                await MainActor.run {
                    hfModel.status = .inCache
                }

                print("Download successful: \(String(describing: snapshot.path))")
                let repo = snapshot.deletingLastPathComponent().deletingLastPathComponent()
                try await hfService.addLocalHFModel(modelAPI: modelAPI, for: repo)
                try await updateHFModels(modelAPI: modelAPI)

                print("Update successful: \(String(describing: snapshot.path))")
            } catch {
                await MainActor.run {
                    hfModel.status = .inPause
                    hfModel.downloadTask = nil
                }
                print("Download interrupted for \(repoId): \(error)")
            }
        }
    }

    func pauseDownload(modelAPI: ModelAPIDescriptor, for repoId: String) async throws {
        let hfModels = self.hfModels[modelAPI.name] ?? []

        guard let hfModel = hfModels.first(where: { $0.repoId == repoId }) else {
            throw SimpleError(message: "Error: HF ModelList not found repoId '\(repoId)'")
        }

        guard hfModel.status == .inDownloading else {
            throw SimpleError(
                message: "Error: modle is \(hfModel.status.raw), not downloading, repoId '\(repoId)'"
            )
        }

        guard let downloader = hfModel.downloader else {
            throw SimpleError(
                message: "Error: modle is \(hfModel.status.raw), no downloader, repoId '\(repoId)'"
            )
        }

        hfModel.status = .inPausing

        await downloader.pause()

        if let taskToCancel = hfModel.downloadTask {
            print("Pausing download task for \(repoId)...")

            taskToCancel.cancel()
            await withTimeout(seconds: 2) {
                _ = await taskToCancel.value
            }

            hfModel.status = .inPause
            print("Download task for \(repoId) confirmed paused.")
        }
    }

    func deleteModel(modelAPI: ModelAPIDescriptor, for repoId: String) async throws {
        let hfModels = self.hfModels[modelAPI.name] ?? []

        guard let hfModel = hfModels.first(where: { $0.repoId == repoId }) else {
            throw SimpleError(message: "Error: HF ModelList not found repoId '\(repoId)'")
        }

        hfModel.status = .inDeleting
        let downloadTaskHandle = hfModel.downloadTask

        await hfModel.downloader?.cancel()

        if let taskToCancel = downloadTaskHandle {
            print("Canceling download task for \(repoId)...")

            taskToCancel.cancel()
            await withTimeout(seconds: 2) {
                _ = await taskToCancel.value
            }

            print("Download task for \(repoId) confirmed stopped.")
        }

        try await self.hfService.deleteRepo(modelAPI: modelAPI, repoId: repoId)

        self.hfModels[modelAPI.name]?.removeAll(where: { $0.repoId == repoId })
    }

    func clearCache(modelAPI: ModelAPIDescriptor) async throws {
        let repoIds = self.hfModels[modelAPI.name]?.map { $0.repoId } ?? []
        for repoId in repoIds {
            try await deleteModel(modelAPI: modelAPI, for: repoId)
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async -> T
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                return await operation()
            }

            group.addTask {
                do {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                } catch {

                }
                return nil
            }

            let result = await group.next()
            group.cancelAll()
            return result ?? nil
        }
    }

    private func creatHFModel(from localHFModel: LocalHFModel) -> HFModel {
        var status: HFModel.Status
        switch localHFModel.status {
        case .inCache:
            status = .inCache
        case .inComplete(let missingFiles):
            status = .inComplete(missingFiles: missingFiles)
        case .needsUpdate:
            status = .needsUpdate
        }

        return HFModel(
            repoId: localHFModel.id,
            repoURL: localHFModel.repoURL,
            status: status,
            expectedFiles: localHFModel.expectedFiles,
            createdAt: localHFModel.createdAt,
            lastCommit: localHFModel.lastCommit,
            totalSize: localHFModel.totalSize
        )
    }

    private func updateHFModels(
        from localHFModels: [LocalHFModel],
        for hfModels: [HFModel]
    ) -> [HFModel] {

        var hfModels = hfModels

        hfModels.removeAll(where: {
            $0.status != .inDownloading &&
            $0.status != .inPause &&
            $0.status != .inPausing &&
            $0.status != .inDeleting
        })

        for localHFModel in localHFModels {
            if !hfModels.contains(where: { $0.repoId == localHFModel.id }) {
                hfModels.append(creatHFModel(from: localHFModel))
            }
        }

        hfModels.sort { $0.createdAt > $1.createdAt }
        return hfModels
    }
}

