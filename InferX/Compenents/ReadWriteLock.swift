import Foundation
import SwiftData
import Dispatch

actor ReadWriteLock {
    private var readCount: Int = 0
    private let semaphore = DispatchSemaphore(value: 1)
    private let readSemaphore = DispatchSemaphore(value: 0)

    func acquireReadLock() async {
        await withCheckedContinuation { continuation in
            semaphore.wait()
            readCount += 1
            if readCount == 1 {
                readSemaphore.wait()
            }
            semaphore.signal()
            continuation.resume()
        }
    }

    func releaseReadLock() async {
        await withCheckedContinuation { continuation in
            semaphore.wait()
            readCount -= 1
            if readCount == 0 {
                readSemaphore.signal()
            }
            semaphore.signal()
            continuation.resume()
        }
    }

    func acquireWriteLock() async {
        await withCheckedContinuation { continuation in
            semaphore.wait()
            readSemaphore.wait()
            continuation.resume()
        }
    }

    func releaseWriteLock() async {
        readSemaphore.signal()
        semaphore.signal()
    }
}
