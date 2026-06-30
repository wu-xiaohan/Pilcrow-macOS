// SPDX-License-Identifier: GPL-3.0-only
//  FileChangeMonitor.swift
//  Pilcrow for macOS
//
//  Watches the open document's file for external changes (write / atomic
//  replace) and publishes the new on-disk content so the editor can offer to
//  reload. The app's own saves (tracked via SaveTracker) don't trigger it.

import Foundation

@MainActor
final class ExternalChangeMonitor: ObservableObject {
    /// Latest on-disk content after an external change (nil = nothing pending).
    @Published var diskContent: String?

    private var source: DispatchSourceFileSystemObject?
    private var url: URL?
    private var debounce: DispatchWorkItem?
    private var generation = 0   // invalidates pending re-watch / read work after stop()

    func start(url: URL?) {
        guard url != self.url else { return }
        self.url = url
        diskContent = nil
        generation &+= 1
        watch()
    }

    func stop() {
        debounce?.cancel(); debounce = nil
        generation &+= 1
        source?.cancel(); source = nil
        url = nil
    }

    func dismiss() { diskContent = nil }

    private func watch() {
        source?.cancel()
        source = nil
        guard let url else { return }

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let gen = generation
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main)
        newSource.setEventHandler { [weak self] in
            guard let self, let source = self.source else { return }
            let flags = source.data
            self.scheduleRead()
            // Atomic saves replace the inode; re-establish the watch (unless stopped).
            if flags.contains(.delete) || flags.contains(.rename) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self, self.generation == gen else { return }
                    self.watch()
                }
            }
        }
        newSource.setCancelHandler { close(descriptor) }   // closes exactly its own fd
        source = newSource
        newSource.resume()
    }

    private func scheduleRead() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.read() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func read() {
        guard let url else { return }
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? Data(contentsOf: url),
                  let content = EncodingDetector.decode(data)?.text else { return }
            // Ignore content the app itself wrote (its own saves).
            if SaveTracker.shared.contains(content) { return }
            Task { @MainActor [weak self] in
                guard let self, self.url == url else { return }   // URL still current
                self.diskContent = content
            }
        }
    }

    deinit { source?.cancel() }
}
