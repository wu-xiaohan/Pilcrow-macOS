// SPDX-License-Identifier: GPL-3.0-only
//  PomodoroTimer.swift
//  Pilcrow for macOS
//
//  App-wide focus/break countdown shown in the header bar. Notifies on phase
//  transitions. The background-sound player observes its `running`/`phase`.

import SwiftUI
import UserNotifications

@MainActor
final class PomodoroTimer: ObservableObject {
    static let shared = PomodoroTimer()

    enum Phase {
        case focus, rest
        var title: String { self == .focus ? "Focus" : "Break" }
    }

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var remaining: Int = 25 * 60
    @Published private(set) var running = false
    @Published private(set) var completedFocusSessions = 0

    @Published var focusMinutes = 25 {
        didSet {
            let clamped = min(180, max(1, focusMinutes))
            if clamped != focusMinutes { focusMinutes = clamped; return }
            if !running && phase == .focus { remaining = focusMinutes * 60 }
        }
    }
    @Published var breakMinutes = 5 {
        didSet {
            let clamped = min(60, max(1, breakMinutes))
            if clamped != breakMinutes { breakMinutes = clamped; return }
            if !running && phase == .rest { remaining = breakMinutes * 60 }
        }
    }

    private var timer: Timer?

    var display: String { String(format: "%d:%02d", remaining / 60, remaining % 60) }
    var isResting: Bool { phase == .rest }

    func startPause() { running ? pause() : start() }

    func start() {
        guard !running else { return }
        running = true
        requestAuthorization()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        running = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        phase = .focus
        remaining = focusMinutes * 60
    }

    /// Skip the current phase (e.g. end a break early and return to focus).
    func skip() {
        if phase == .focus {
            phase = .rest
            remaining = breakMinutes * 60
        } else {
            phase = .focus
            remaining = focusMinutes * 60
        }
    }

    private func tick() {
        if remaining > 0 {
            remaining -= 1
        } else {
            advancePhase()
        }
    }

    private func advancePhase() {
        if phase == .focus {
            completedFocusSessions += 1
            phase = .rest
            remaining = breakMinutes * 60
            notify("Time for a break", "Focus session complete — take \(breakMinutes) minutes.")
        } else {
            phase = .focus
            remaining = focusMinutes * 60
            notify("Back to focus", "Break's over — let's write.")
        }
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
