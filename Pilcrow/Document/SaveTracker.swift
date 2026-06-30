// SPDX-License-Identifier: GPL-3.0-only
//  SaveTracker.swift
//  Pilcrow for macOS
//
//  App-wide record of content the app has written to disk, so the file-change
//  monitor can distinguish the app's own (auto)saves from genuine external
//  edits — without being fooled by transient typing states.

import Foundation

final class SaveTracker: @unchecked Sendable {
    static let shared = SaveTracker()

    private let lock = NSLock()
    private var hashes: [Int] = []

    func record(_ content: String) {
        let hash = content.hashValue
        lock.lock(); defer { lock.unlock() }
        guard hashes.last != hash else { return }
        hashes.append(hash)
        if hashes.count > 20 { hashes.removeFirst(hashes.count - 20) }
    }

    func contains(_ content: String) -> Bool {
        let hash = content.hashValue
        lock.lock(); defer { lock.unlock() }
        return hashes.contains(hash)
    }
}
