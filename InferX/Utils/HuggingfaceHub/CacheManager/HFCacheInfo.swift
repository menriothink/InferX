//
//  HFCacheInfo.swift
//  HuggingfaceHub
//
//  Created by John Mai on 2024/11/11.
//

import Foundation

struct HFCacheInfo {
    let sizeOnDisk: Int
    let repos: Set<CachedRepoInfo>
    let warnings: [CacheManager.CorruptedError]

    var sizeOnDiskStr: String {
        return ByteCountFormatter.string(fromByteCount: Int64(sizeOnDisk), countStyle: .file)
    }
}
