//
//  CachedRevisionInfo.swift
//  HuggingfaceHub
//
//  Created by John Mai on 2024/11/11.
//

import Foundation

struct CachedRevisionInfo {
    let commitHash: String
    let snapshotPath: URL
    let sizeOnDisk: Int
    let files: Set<CachedFileInfo>
    let refs: Set<String>
    let lastModified: TimeInterval

    var lastModifiedStr: String {
        Date(timeIntervalSince1970: lastModified).timeAgoDisplay()
    }

    var sizeOnDiskStr: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeOnDisk), countStyle: .file)
    }

    var nbFiles: Int {
        files.count
    }
}

extension CachedRevisionInfo: Hashable {}
