// SPDX-License-Identifier: GPL-3.0-only
//  StatsController.swift
//  Pilcrow for macOS
//
//  Debounces document statistics off the main thread and publishes them to the
//  stats bar.

import SwiftUI

@MainActor
final class StatsController: ObservableObject {
    @Published var stats = DocumentStats.empty
    private var task: Task<Void, Never>?

    func update(_ text: String) {
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            let computed = await Task.detached(priority: .utility) {
                StatsEngine.compute(text)
            }.value
            if Task.isCancelled { return }
            self?.stats = computed
        }
    }
}
