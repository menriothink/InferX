//
//  WeakFileLock.swift
//  HuggingfaceHub
//
//  Created by John Mai on 2025/2/17.
//

import Foundation
import Darwin

public enum WeakFileLockError: Error, LocalizedError {
    case timeout

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Timeout while waiting to acquire lock"
        }
    }
}

final class WeakFileLock {
    private let lockPath: String
    private var fileDescriptor: Int32?
    private let timeout: TimeInterval?
    private let logInterval: TimeInterval = 10

    init(lockPath: String, timeout: TimeInterval?) {
        self.lockPath = lockPath
        self.timeout = timeout
    }

    init(lockPath: String) {
        self.lockPath = lockPath
        self.timeout = nil
    }

    func acquire() async throws {
        let start = Date()
        while true {
            let elapsed = Date().timeIntervalSince(start)
            if let timeout, elapsed >= timeout {
                throw WeakFileLockError.timeout
            }

            if try attemptLock() {
                return
            }

            NSLog(
                "Still waiting to acquire lock on \(lockPath) (elapsed: \(String(format: "%.1f", Date().timeIntervalSince(start))) seconds)"
            )

            let nextTimeout: TimeInterval =
                if let timeout = timeout {
                    min(logInterval, timeout - elapsed)
                } else {
                    logInterval
                }

            try await Task.sleep(nanoseconds: UInt64(nextTimeout * 1_000_000_000))
        }
    }

    func release() {
        if let fd = fileDescriptor {
            flock(fd, LOCK_UN)
            close(fd)
            fileDescriptor = nil
        }

        try? FileManager.default.removeItem(atPath: lockPath)
    }

    private func attemptLock() throws -> Bool {
        if fileDescriptor == nil {
            FileManager.default.createFile(atPath: lockPath, contents: nil, attributes: nil)
            fileDescriptor = open(lockPath, O_CREAT | O_RDWR, 0o600)
        }

        guard let fd = fileDescriptor else {
            return false
        }

        let result = flock(fd, LOCK_EX | LOCK_NB)
        return result == 0
    }
}
