// SPDX-License-Identifier: GPL-3.0-only
//  PomodoroView.swift
//  Pilcrow for macOS
//
//  Minimalist header-bar countdown with a control popover.

import SwiftUI

struct PomodoroToolbar: View {
    @ObservedObject private var timer = PomodoroTimer.shared
    @State private var showingPopover = false

    var body: some View {
        Button {
            showingPopover.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: timer.isResting ? "cup.and.saucer" : "timer")
                if timer.running || timer.remaining != timer.focusMinutes * 60 {
                    Text(timer.display).monospacedDigit()
                }
            }
            .foregroundStyle(timer.running ? .primary : .secondary)
        }
        .help("Pomodoro timer")
        .popover(isPresented: $showingPopover, arrowEdge: .bottom) { popover }
    }

    private var popover: some View {
        VStack(spacing: 12) {
            Text(timer.phase.title)
                .font(.headline)
                .foregroundStyle(timer.isResting ? .green : .primary)
            Text(timer.display)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()

            HStack {
                Button(timer.running ? "Pause" : "Start") { timer.startPause() }
                    .keyboardShortcut(.defaultAction)
                Button("Skip") { timer.skip() }
                Button("Reset") { timer.reset() }
            }

            Divider()

            durationRow("Focus", value: $timer.focusMinutes, range: 1...180)
            durationRow("Break", value: $timer.breakMinutes, range: 1...60)

            Text("Completed sessions: \(timer.completedFocusSessions)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 260)
    }

    private func durationRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 8) {
            Text(label)
            Spacer()
            TextField("", value: value, format: .number)
                .frame(width: 46)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
            Stepper("", value: value, in: range).labelsHidden()
            Text("min").foregroundStyle(.secondary)
        }
    }
}
