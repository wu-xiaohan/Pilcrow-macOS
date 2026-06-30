// SPDX-License-Identifier: GPL-3.0-only
//  RecoveryStore.swift
//  Pilcrow for macOS
//
//  A lightweight crash-recovery safety net that is additive to (not a
//  replacement for) the OS autosave/Versions on saved files. It debounces a
//  snapshot of the editor text to Application Support; on open, if a snapshot
//  differs from the file on disk, it offers to restore the unsaved edits that
//  survived an unexpected quit. Snapshots that match the file are cleaned up.

import Foundation
import CryptoKit

@MainActor
final class RecoveryStore: ObservableObject {
    /// Recovered unsaved text to offer the user (nil = nothing to restore).
    @Published var pendingRestore: String?

    private var url: URL?
    private var debounce: DispatchWorkItem?

    /// Call when a document opens (and when its URL changes). `currentText` is
    /// the just-loaded file content.
    func begin(url: URL?, currentText: String) {
        self.url = url
        guard let url else { pendingRestore = nil; return }

        let snapshot = Self.snapshotURL(for: url)
        guard let data = try? Data(contentsOf: snapshot),
              let saved = String(data: data, encoding: .utf8) else {
            pendingRestore = nil
            return
        }
        if saved != currentText {
            pendingRestore = saved              // unsaved edits survived a crash
        } else {
            pendingRestore = nil
            try? FileManager.default.removeItem(at: snapshot)   // stale: matches the file
        }
    }

    /// Call on every edit; writes a snapshot a couple of seconds after typing stops.
    func note(_ text: String) {
        guard url != nil else { return }
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.write(text) }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    func discard() {
        pendingRestore = nil
        if let url { try? FileManager.default.removeItem(at: Self.snapshotURL(for: url)) }
    }

    private func write(_ text: String) {
        guard let url else { return }
        try? Data(text.utf8).write(to: Self.snapshotURL(for: url))
    }

    // MARK: - Storage

    private static var directory: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Pilcrow/Recovery", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func snapshotURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.path.utf8))
        let key = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(key).appendingPathExtension("md")
    }
}
