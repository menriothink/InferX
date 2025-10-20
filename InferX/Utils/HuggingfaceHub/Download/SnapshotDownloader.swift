//
//  SnapshotDownloader.swift
//  HuggingfaceHub
//
//  Created by John Mai on 2024/11/12.
//

import Foundation
import Semaphore

actor SnapshotDownloader {
    let repoId: String
    let options: Options
    var tasks: [String: FileDownloader] = [:]
    var extendedProgress: ExtendedProgresss = ExtendedProgresss()

    init(repoId: String, options: Options = .init()) {
        self.repoId = repoId
        self.options = options
    }

    private func progressHandler(
        filename: String,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if let progress = self.extendedProgress.individualProgresses[filename]?.progress {
            progress.totalUnitCount = totalBytesExpectedToWrite
            progress.completedUnitCount = totalBytesWritten
            self.options.onProgress(self.extendedProgress)
        }
    }
    
    private func progressCompleted(filename: String, url: URL, fileSize: Int64?) {
        var size = fileSize
        if size == nil {
            let realFileSize = getSizeOfAliasTarget(at: url)
            if let realSize = realFileSize {
                size = realSize
            } else {
                print("Error: Could not parse the real size from pointer file \(url.path).")
            }
        }
                
        if let progress = self.extendedProgress.individualProgresses[filename]?.progress {
            if progress.totalUnitCount <= 0 {
                progress.totalUnitCount = Int64(size ?? 100)
            }
            progress.completedUnitCount = progress.totalUnitCount
        } else {
            let fileProgress = Progress(
                totalUnitCount: Int64(size ?? 100),
                parent: self.extendedProgress.totalProgress,
                pendingUnitCount: Int64(size ?? 100)
            )
            self.extendedProgress.individualProgresses[filename] = IndividualProgress(
                progress: fileProgress,
                downloadingFileName: filename
            )
            fileProgress.completedUnitCount = fileProgress.totalUnitCount
        }
        self.options.onProgress(self.extendedProgress)
    }

    private func getSizeOfAliasTarget(at aliasURL: URL) -> Int64? {
        do {
            let targetURL = try URL(resolvingAliasFileAt: aliasURL, options: [])
            
            let attributes = try FileManager.default.attributesOfItem(atPath: targetURL.path)
            
            if let fileSize = attributes[.size] as? NSNumber {
                return fileSize.int64Value
            }
            
        } catch {
            print("Error: Could not resolve alias or get target file attributes. URL: \(aliasURL.path). Error details: \(error)")
        }
        
        return nil
    }
    
    func innerDownload(
        filename: String,
        commitHash: String
    ) async throws {
        try Task.checkCancellation()

        let task =
            tasks[filename]
            ?? FileDownloader(
                repoId: repoId,
                filename: filename,
                options: .init(
                    repoType: options.repoType,
                    revision: commitHash,
                    libraryName: options.libraryName,
                    libraryVersion: options.libraryVersion,
                    cacheDir: options.cacheDir,
                    localDir: options.localDir,
                    userAgent: options.userAgent,
                    forceDownload: options.forceDownload,
                    proxies: options.proxies,
                    etagTimeout: options.etagTimeout,
                    token: options.token,
                    headers: options.headers,
                    endpoint: options.endpoint,
                    extendedProgress: self.extendedProgress,
                    onProgress: { totalBytesWritten, totalBytesExpectedToWrite in
                        Task {
                            try Task.checkCancellation()
                            await self.progressHandler(
                                filename: filename,
                                totalBytesWritten: totalBytesWritten,
                                totalBytesExpectedToWrite: totalBytesExpectedToWrite
                            )
                        }
                    },
                    quiet: options.quiet
                )
            )

        tasks[filename] = task

        let (url, fileSize) = try await task.download()

        progressCompleted(filename: filename, url: url, fileSize: fileSize)
    }

    @discardableResult
    func download() async throws -> URL {
        let revision: String = options.revision ?? Constants.defaultRevision

        let storageFolder = options.cacheDir.appendingPathComponent(
            HFUtility.repoFolderName(
                repoId: repoId,
                repoType: options.repoType
            )
        )

        var repoInfo: RepoInfoType?

        if !options.localFilesOnly {
            let api = HFApi(
                endpoint: options.endpoint,
                libraryName: options.libraryName,
                libraryVersion: options.libraryVersion,
                userAgent: options.userAgent,
                headers: options.headers
            )

            repoInfo = try await api.repoInfo(
                repoId: repoId,
                options: .init(
                    revision: revision,
                    token: options.token
                )
            )
        }

        if repoInfo == nil {
            var commitHash: String?

            if let revision = options.revision, revision.contains(#/^[0-9a-f]{40}$/#) {
                commitHash = revision
            } else {
                let refURL = storageFolder.appendingPathComponent("refs/\(revision)")
                if refURL.exists() {
                    commitHash = try String(contentsOf: refURL, encoding: .utf8)
                }
            }

            if let commitHash {
                let snapshotFolder = storageFolder.appendingPathComponent("snapshots/\(commitHash)")
                if snapshotFolder.exists() {
                    return snapshotFolder
                }
            }

            if let localDir = options.localDir,
                localDir.isDirectory(),
                let contents = try? FileManager.default.contentsOfDirectory(
                    at: localDir,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                ),
                !contents.isEmpty
            {
                return localDir
            }
        }

        guard let commitHash = repoInfo?.sha else {
            throw Error.missingRevision
        }

        guard let siblings = repoInfo?.siblings else {
            throw Error.missingSiblings
        }

        let filteredRepoFiles = Utility.filterRepoObjects(
            items: siblings.map(\.rfilename),
            allowPatterns: options.allowPatterns,
            ignorePatterns: options.ignorePatterns
        )

        let snapshotFolder = storageFolder.appendingPathComponent("snapshots/\(commitHash)")

        if options.revision != commitHash {
            let refURL = storageFolder.appendingPathComponent("refs/\(revision)")

            do {
                try FileManager.default.createDirectory(
                    at: refURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                try commitHash.write(
                    to: refURL,
                    atomically: true,
                    encoding: .utf8
                )
            } catch {
                NSLog("Ignored error while writing commit hash to \(refURL): \(error).")
            }
        }

        self.extendedProgress.totalProgress.totalUnitCount = Int64(filteredRepoFiles.count)
        /*self.extendedProgress.totalProgress.completedUnitCount = Int64(filteredRepoFiles.filter {
            if let fileProgress = self.extendedProgress.individualProgresses[$0]?.progress,
               fileProgress.completedUnitCount != 0 {
                return fileProgress.completedUnitCount == fileProgress.totalUnitCount
            } else {
                return false
            }
        }.count)*/

        if Constants.hfHubEnableHFTransfer {
            for file in filteredRepoFiles {
                if self.extendedProgress.individualProgresses[file] == nil {
                    let fileProgress = Progress(
                        totalUnitCount: 0,
                        parent: self.extendedProgress.totalProgress,
                        pendingUnitCount: 1
                    )
                    self.extendedProgress.individualProgresses[file] = IndividualProgress(
                        progress: fileProgress,
                        downloadingFileName: file
                    )
                }

                try await innerDownload(
                    filename: file,
                    commitHash: commitHash
                )
            }

            options.onProgress(extendedProgress)
        } else {
            let semaphore = AsyncSemaphore(value: options.maxWorkers)

            try await withThrowingTaskGroup(of: Void.self) { group in
                for file in filteredRepoFiles {
                    let file = file
                    let commitHash = commitHash

                    if self.extendedProgress.individualProgresses[file] == nil {
                        let fileProgress = Progress(
                            totalUnitCount: 0,
                            parent: self.extendedProgress.totalProgress,
                            pendingUnitCount: 1
                        )
                        self.extendedProgress.individualProgresses[file] = IndividualProgress(
                            progress: fileProgress,
                            downloadingFileName: file
                        )
                    }

                    await semaphore.wait()

                    group.addTask { [weak self] in
                        defer {
                            semaphore.signal()
                        }

                        try await self?.innerDownload(
                            filename: file,
                            commitHash: commitHash
                        )
                    }
                }

                try await group.waitForAll()
            }
        }

        return snapshotFolder
    }

    func cancel() async {
        for (_, task) in tasks {
            await task.cancel()
        }
        tasks = [:]
    }

    func pause() async {
        for (_, task) in tasks {
            await task.pause()
        }
    }
}

extension SnapshotDownloader {
    struct Options: Sendable {
        let repoType: RepoType
        let revision: String?
        let cacheDir: URL
        let localDir: URL?
        let libraryName: String?
        let libraryVersion: String?
        let userAgent: [String: String]?
        let proxies: [String: String]?
        let etagTimeout: TimeInterval
        let forceDownload: Bool
        let token: String?
        let localFilesOnly: Bool
        let allowPatterns: [String]?
        let ignorePatterns: [String]?
        let maxWorkers: Int
        let headers: [String: String]?
        let endpoint: String?
        let onProgress: @Sendable (ExtendedProgresss) -> Void
        let quiet: Bool
        let checkLocalStatusOnly: Bool

        init(
            repoType: RepoType = .model,
            revision: String? = nil,
            cacheDir: URL = URL(fileURLWithPath: Constants.hfHubCache.expandingTildeInPath).standardized,
            localDir: URL? = nil,
            libraryName: String? = nil,
            libraryVersion: String? = nil,
            userAgent: [String: String]? = nil,
            proxies: [String: String]? = nil,
            etagTimeout: TimeInterval = Constants.defaultEtagTimeout,
            forceDownload: Bool = false,
            token: String? = nil,
            localFilesOnly: Bool = false,
            allowPatterns: [String]? = nil,
            ignorePatterns: [String]? = nil,
            maxWorkers: Int = 8,
            headers: [String: String]? = nil,
            endpoint: String? = nil,
            onProgress: @Sendable @escaping (ExtendedProgresss) -> Void = { _ in },
            quiet: Bool = true,
            checkLocalStatusOnly: Bool = false
        ) {
            self.repoType = repoType
            self.revision = revision
            self.cacheDir = cacheDir
            self.localDir = localDir
            self.libraryName = libraryName
            self.libraryVersion = libraryVersion
            self.userAgent = userAgent
            self.proxies = proxies
            self.etagTimeout = etagTimeout
            self.forceDownload = forceDownload
            self.token = token
            self.localFilesOnly = localFilesOnly
            self.allowPatterns = allowPatterns
            self.ignorePatterns = ignorePatterns
            self.maxWorkers = maxWorkers
            self.headers = headers
            self.endpoint = endpoint
            self.onProgress = onProgress
            self.quiet = quiet
            self.checkLocalStatusOnly = checkLocalStatusOnly
        }
    }
}

extension SnapshotDownloader {
    enum Error: Swift.Error, LocalizedError, Equatable {
        case missingRevision
        case missingSiblings

        var errorDescription: String? {
            switch self {
            case .missingRevision:
                "Repo info returned from server must have a revision sha."
            case .missingSiblings:
                "Repo info returned from server must have a siblings list."
            }
        }
    }
}
