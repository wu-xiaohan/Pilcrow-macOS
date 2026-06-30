// SPDX-License-Identifier: GPL-3.0-only
//  SoundLibrary.swift
//  Pilcrow for macOS
//
//  Bundled ambient tracks (from the pilcrow data/sounds set): an instrument
//  (piano/cello) playlist, a nature playlist, and a calm break track.

import Foundation

enum SoundLibrary {
    static func tracks(for source: AmbientPlayer.Source) -> [URL] {
        let subdirectory: String
        switch source {
        case .piano:  subdirectory = "Sounds/instrument"
        case .nature: subdirectory = "Sounds/nature"
        case .ownMusic: return []
        }
        let urls = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: subdirectory) ?? []
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Calm track played during Pomodoro breaks.
    static var breakTrack: URL? {
        Bundle.main.url(forResource: "break-music", withExtension: "mp3", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: "break-music", withExtension: "mp3")
    }
}
