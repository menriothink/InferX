//
//  CacheManager.swift
//  HuggingfaceHub
//
//  Created by John Mai on 2024/11/11.
//

import Foundation

class CacheManager {
    let cacheDir: URL
    let fileManager = FileManager.default

    init(cacheDir: URL) {
        self.cacheDir = cacheDir
    }

    func scanCacheDir() throws -> HFCacheInfo {
        var repos = Set<CachedRepoInfo>()
        var warnings = [CorruptedError]()

        let repoURLs = try fileManager.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for repoURL in repoURLs {
            if repoURL.lastPathComponent == ".locks" {
                continue
            }

            do {
                try repos.insert(scanCachedRepo(repoURL))
            } catch let error as CorruptedError {
                warnings.append(error)
            }
        }

        return HFCacheInfo(
            sizeOnDisk: repos.reduce(0) { $0 + $1.sizeOnDisk },
            repos: repos,
            warnings: warnings
        )
    }

    func scanRefsByHash(_ repoURL: URL) throws -> [String: Set<String>] {
        let refsPath = repoURL.appendingPathComponent("refs")
        var refsByHash: [String: Set<String>] = [:]
        if refsPath.exists() {
            if refsPath.isFile() {
                throw CorruptedError.refsNotDirectory(refsPath)
            }

            if let enumerator = fileManager.enumerator(
                at: refsPath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                while let refURL = enumerator.nextObject() as? URL {
                    let resourceValues = try refURL.resourceValues(forKeys: [.isDirectoryKey])
                    guard let isDirectory = resourceValues.isDirectory, !isDirectory else { continue }
                    let refName = refURL.path.replacingOccurrences(of: refsPath.path + "/", with: "")
                    let commitHash = try String(contentsOf: refURL, encoding: .utf8).trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    refsByHash[commitHash, default: []].insert(refName)
                }
            }
        }

        return refsByHash
    }

    func scanCachedRepo(_ repoURL: URL) throws -> CachedRepoInfo {
        if !repoURL.hasDirectoryPath {
            throw CorruptedError.notDirectory(repoURL)
        }

        let (repoType, repoId) = try Self.parseRepo(repoURL)

        let snapshotsPath = repoURL.appendingPathComponent("snapshots")

        guard snapshotsPath.isDirectory() else {
            throw CorruptedError.snapshotsNotExist(snapshotsPath)
        }

        var refsByHash = try scanRefsByHash(repoURL)
        var blobStats = [URL: [FileAttributeKey: Any]]()
        var cachedRevisions = Set<CachedRevisionInfo>()

        let snapshotURLs = try fileManager.contentsOfDirectory(
            at: snapshotsPath,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for revisionURL in snapshotURLs {
            if Constants.filesToIgnore.contains(revisionURL.lastPathComponent) {
                continue
            }

            let revisionInfo = try scanRevision(
                revisionURL,
                refsByHash: &refsByHash,
                blobStats: &blobStats
            )
            cachedRevisions.insert(revisionInfo)
        }

        guard refsByHash.isEmpty else {
            throw CorruptedError.refersToMissingCommitHashes(refsByHash, repoURL)
        }

        let repoStats = try calculateRepoStats(from: blobStats, at: repoURL)

        return CachedRepoInfo(
            repoId: repoId,
            repoType: repoType,
            repoPath: repoURL,
            sizeOnDisk: repoStats.sizeOnDisk,
            nbFiles: blobStats.count,
            revisions: cachedRevisions,
            lastAccessed: repoStats.lastAccessed,
            lastModified: repoStats.lastModified
        )
    }

    static func parseRepo(_ repoURL: URL) throws -> (RepoType, String) {
        let repoName = repoURL.lastPathComponent

        guard let separatorRange = repoName.range(of: "--") else {
            throw CorruptedError.notValidHuggingFaceCacheDirectory(repoURL)
        }

        var repoType = String(repoName[..<separatorRange.lowerBound])
        if repoType.hasSuffix("s") {
            repoType.removeLast()
        }

        let repoId = repoName[separatorRange.upperBound...].replacingOccurrences(of: "--", with: "/")

        guard let repoType = RepoType(rawValue: repoType) else {
            throw CorruptedError.repoTypeMismatch(repoType, repoURL)
        }

        return (repoType, repoId)
    }
}

private extension CacheManager {
    func scanRevision(
        _ revisionURL: URL,
        refsByHash: inout [String: Set<String>],
        blobStats: inout [URL: [FileAttributeKey: Any]]
    ) throws -> CachedRevisionInfo {
        if revisionURL.isFile() {
            throw CorruptedError.revisionNotDirectory(revisionURL)
        }

        let cachedFiles = try scanFilesInRevision(revisionURL, blobStats: &blobStats)
        let revisionLastModified = calculateRevisionLastModified(for: revisionURL, basedOn: cachedFiles)
        let commitHash = revisionURL.lastPathComponent
        
        return CachedRevisionInfo(
            commitHash: commitHash,
            snapshotPath: revisionURL,
            sizeOnDisk: cachedFiles.reduce(0) { $0 + $1.sizeOnDisk },
            files: cachedFiles,
            refs: refsByHash.removeValue(forKey: commitHash) ?? [],
            lastModified: revisionLastModified
        )
    }

    func scanFilesInRevision(
        _ revisionURL: URL,
        blobStats: inout [URL: [FileAttributeKey: Any]]
    ) throws -> Set<CachedFileInfo> {
        var cachedFiles = Set<CachedFileInfo>()

        guard let enumerator = fileManager.enumerator(
            at: revisionURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return cachedFiles
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.isDirectory() {
                continue
            }

            let blobURL = fileURL.resolvingSymlinksInPath()
            guard blobURL.exists() else {
                throw CorruptedError.missingBlob(blobURL)
            }

            if blobStats[blobURL] == nil {
                blobStats[blobURL] = try fileManager.attributesOfItem(atPath: blobURL.path)
            }
            
            let attributes = blobStats[blobURL]
            let creationDate = (attributes?[.creationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let modificationDate = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let sizeOnDisk = attributes?[.size] as? Int ?? 0

            cachedFiles.insert(
                CachedFileInfo(
                    fileName: fileURL.lastPathComponent,
                    filePath: fileURL,
                    blobPath: blobURL,
                    sizeOnDisk: sizeOnDisk,
                    blobLastAccessed: creationDate,
                    blobLastModified: modificationDate
                )
            )
        }
        
        return cachedFiles
    }

    func calculateRevisionLastModified(
        for revisionURL: URL,
        basedOn cachedFiles: Set<CachedFileInfo>
    ) -> TimeInterval {
        if cachedFiles.isEmpty {
            if let attributes = try? fileManager.attributesOfItem(atPath: revisionURL.path),
               let modDate = attributes[.modificationDate] as? Date {
                return modDate.timeIntervalSince1970
            } else {
                return 0
            }
        } else {
            return cachedFiles.map(\.blobLastModified).max() ?? 0
        }
    }

    func calculateRepoStats(
        from blobStats: [URL: [FileAttributeKey: Any]],
        at repoURL: URL
    ) throws -> (sizeOnDisk: Int, lastAccessed: TimeInterval, lastModified: TimeInterval) {
        let sizeOnDisk = blobStats.values.reduce(0) { $0 + Int(($1[.size] as? Int64) ?? 0) }

        let lastAccessed: TimeInterval
        let lastModified: TimeInterval

        if !blobStats.isEmpty {
            lastAccessed = blobStats.values
                .compactMap { $0[.creationDate] as? Date }
                .map(\.timeIntervalSince1970)
                .max() ?? 0
            lastModified = blobStats.values
                .compactMap { $0[.modificationDate] as? Date }
                .map(\.timeIntervalSince1970)
                .max() ?? 0
        } else {
            if let attributes = try? fileManager.attributesOfItem(atPath: repoURL.path) {
                lastAccessed = (attributes[.creationDate] as? Date)?.timeIntervalSince1970 ?? 0
                lastModified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            } else {
                lastAccessed = 0
                lastModified = 0
            }
        }
        
        return (sizeOnDisk, lastAccessed, lastModified)
    }
}


extension CacheManager {
    enum Error: LocalizedError {
        case notFound(URL)

        var errorDescription: String {
            switch self {
            case .notFound(let url):
                "Cache directory not found or not a directory: \(url.path). Please use `cacheDir` argument or set `HF_HUB_CACHE` environment variable."
            }
        }
    }
}

extension CacheManager {
    enum CorruptedError: LocalizedError {
        case notDirectory(URL)
        case notValidHuggingFaceCacheDirectory(URL)
        case repoTypeMismatch(String, URL)
        case snapshotsNotExist(URL)
        case revisionNotDirectory(URL)
        case refsNotDirectory(URL)
        case missingBlob(URL)
        case refersToMissingCommitHashes([String: Set<String>], URL)

        var errorDescription: String? {
            switch self {
            case .notDirectory(let url):
                "Repo path is not a directory: \(url.path)"
            case .notValidHuggingFaceCacheDirectory(let url):
                "Repo path is not a valid HuggingFace cache directory: \(url.path)"
            case .repoTypeMismatch(let type, let url):
                "Repo type must be `dataset`, `model` or `space`, found `\(type)` (\(url.path))"
            case .snapshotsNotExist(let url):
                "Snapshots dir doesn't exist in cached repo: \(url.path)"
            case .revisionNotDirectory(let url):
                "Snapshots folder corrupted. Found a file: \(url.path)"
            case .missingBlob(let url):
                "Blob missing (broken symlink): \(url.path)"
            case .refersToMissingCommitHashes(let refsByHash, let url):
                "Reference(s) refer to missing commit hashes: \(refsByHash) (\(url.path))."
            case .refsNotDirectory(let url):
                "Refs directory cannot be a file: \(url.path)"
            }
        }
    }
}

extension CacheManager {
    func cleanupRepoKeepLatest(_ repoURL: URL) throws -> Int64 {
        let repoInfo = try scanCachedRepo(repoURL)

        guard let latestRevision = repoInfo.revisions.max(
            by: { $0.lastModified < $1.lastModified }
        ) else {
            throw CorruptedError.snapshotsNotExist(repoURL.appendingPathComponent("snapshots"))
        }

        let latestBlobs = Set(latestRevision.files.map { $0.blobPath })

        var allOtherBlobs = Set<URL>()
        for revision in repoInfo.revisions {
            if revision.commitHash != latestRevision.commitHash {
                allOtherBlobs.formUnion(revision.files.map { $0.blobPath })
            }
        }

        let blobsToDelete = allOtherBlobs.subtracting(latestBlobs)

        var freedSpace: Int64 = 0
        for blobURL in blobsToDelete {
            if let attributes = try? fileManager.attributesOfItem(atPath: blobURL.path),
               let fileSize = attributes[.size] as? Int64 {
                freedSpace += fileSize
            }
        }

        for revision in repoInfo.revisions {
            if revision.commitHash != latestRevision.commitHash {
                try fileManager.removeItem(at: revision.snapshotPath)
            }
        }

        for blobURL in blobsToDelete {
            if blobURL.exists() {
                try fileManager.removeItem(at: blobURL)
            }
        }

        try cleanupRefs(repoURL, keepCommitHash: latestRevision.commitHash)

        return freedSpace
    }

    private func cleanupRefs(_ repoURL: URL, keepCommitHash: String) throws {
        let refsPath = repoURL.appendingPathComponent("refs")

        guard refsPath.exists() && refsPath.isDirectory() else { return }

        if let enumerator = fileManager.enumerator(
            at: refsPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            while let refURL = enumerator.nextObject() as? URL {
                let resourceValues = try refURL.resourceValues(forKeys: [.isDirectoryKey])
                guard let isDirectory = resourceValues.isDirectory, !isDirectory else { continue }

                let commitHash = try String(contentsOf: refURL, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if commitHash != keepCommitHash {
                    try fileManager.removeItem(at: refURL)
                }
            }
        }
    }
}

extension CacheManager {
    func cleanupAllReposKeepLatest() throws -> Int64 {
        let cacheInfo = try scanCacheDir()
        var totalFreedSpace: Int64 = 0
        var errors: [Error] = []

        for repoInfo in cacheInfo.repos {
            do {
                let freedSpace = try cleanupRepoKeepLatest(repoInfo.repoPath)
                totalFreedSpace += freedSpace
                print("✅ Successfully cleaned \(repoInfo.repoId), freed space: \(ByteCountFormatter.string(fromByteCount: freedSpace, countStyle: .file))")
            } catch {
                errors.append(error as! CacheManager.Error) // Assuming it's a CacheManager.Error for consistent error handling
                print("❌ Failed to clean \(repoInfo.repoId): \(error.localizedDescription)")
            }
        }

        if !errors.isEmpty {
            print("⚠️ Some repositories failed to clean up. Please check permissions or file status.")
        }

        return totalFreedSpace
    }
}
