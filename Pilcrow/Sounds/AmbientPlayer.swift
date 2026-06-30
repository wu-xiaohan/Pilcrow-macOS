// SPDX-License-Identifier: GPL-3.0-only
//  AmbientPlayer.swift
//  Pilcrow for macOS
//
//  One ambient player driven by three header icons (piano / nature / your own
//  music). Each source is a playlist that advances track to track; bundled
//  categories shuffle, your own music plays in order. Syncs to the Pomodoro
//  timer: pauses when it pauses and plays the calm break track during breaks.

import AVFoundation
import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class AmbientPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AmbientPlayer()

    enum Source: String, CaseIterable { case piano, nature, ownMusic }

    @Published private(set) var active: Source?
    @Published var volume: Double = 0.5 { didSet { player?.volume = currentVolume } }
    @Published private(set) var userTracks: [URL] = []

    private var player: AVAudioPlayer?
    private var queue: [URL] = []
    private var index = 0
    private var loadedSource: Source?
    private var bag = Set<AnyCancellable>()
    private let userMusicKey = "user-music"

    private override init() {
        super.init()
        userTracks = (UserDefaults.standard.stringArray(forKey: userMusicKey) ?? []).map { URL(fileURLWithPath: $0) }
        let timer = PomodoroTimer.shared
        timer.$running.dropFirst().sink { [weak self] running in self?.timerRunningChanged(running) }.store(in: &bag)
        timer.$phase.dropFirst().sink { [weak self] _ in self?.phaseChanged() }.store(in: &bag)
    }

    private var resting: Bool { PomodoroTimer.shared.isResting && PomodoroTimer.shared.running }
    private var currentVolume: Float { Float(volume) * (resting ? 0.85 : 1.0) }

    // MARK: - Controls

    func toggle(_ source: Source) {
        if source == .ownMusic && userTracks.isEmpty { addMusic(); return }
        if active == source {
            stop()
        } else {
            active = source
            loadedSource = nil
            playCurrent()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        active = nil
    }

    /// Skip to the next track. If `source` isn't the active one, start it.
    func next(_ source: Source) {
        guard active == source else { toggle(source); return }
        guard !queue.isEmpty else { playCurrent(); return }
        index = (index + 1) % queue.count
        startPlayer(queue[index], loop: queue.count == 1)
    }

    func addMusic() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !userTracks.contains(url) { userTracks.append(url) }
        saveUserTracks()
        if active == nil { active = .ownMusic; loadedSource = nil; playCurrent() }
    }

    func removeMusic(_ url: URL) {
        userTracks.removeAll { $0 == url }
        saveUserTracks()
        if active == .ownMusic {
            if userTracks.isEmpty { stop() } else { loadedSource = nil; playCurrent() }
        }
    }

    private func saveUserTracks() {
        UserDefaults.standard.set(userTracks.map(\.path), forKey: userMusicKey)
    }

    // MARK: - Playback

    private func tracks(for source: Source) -> [URL] {
        switch source {
        case .piano, .nature: return SoundLibrary.tracks(for: source)
        case .ownMusic: return userTracks
        }
    }

    private func playCurrent() {
        // Calm break track takes over during Pomodoro breaks — even when no
        // ambient source is selected.
        if resting, let breakURL = SoundLibrary.breakTrack {
            startPlayer(breakURL, loop: true)
            return
        }

        guard let active else { player?.stop(); player = nil; return }

        let list = tracks(for: active)
        guard !list.isEmpty else {
            if active != .ownMusic, let url = AudioGenerator.loopURL(for: active == .piano ? "piano" : "nature") {
                startPlayer(url, loop: true)
            }
            return
        }
        if loadedSource != active {
            queue = (active == .ownMusic) ? list : list.shuffled()
            index = 0
            loadedSource = active
        }
        index = min(index, queue.count - 1)
        startPlayer(queue[index], loop: queue.count == 1)
    }

    private func startPlayer(_ url: URL, loop: Bool) {
        player?.stop()
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        newPlayer.delegate = self
        newPlayer.numberOfLoops = loop ? -1 : 0
        newPlayer.volume = currentVolume
        player = newPlayer
        newPlayer.play()
    }

    private func timerRunningChanged(_ running: Bool) {
        if running {
            if player != nil { player?.play() } else { playCurrent() }
        } else {
            player?.pause()
        }
    }

    private func phaseChanged() {
        playCurrent()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.advanceTrack() }
    }

    private func advanceTrack() {
        guard active != nil, !resting, queue.count > 1 else { return }
        index = (index + 1) % queue.count
        startPlayer(queue[index], loop: false)
    }
}
