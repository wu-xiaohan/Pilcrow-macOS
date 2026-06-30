// SPDX-License-Identifier: GPL-3.0-only
//  SoundsToolbar.swift
//  Pilcrow for macOS
//
//  Three header-bar ambient-sound icons. Click toggles a source; triple-click
//  any icon reveals a volume slider.

import SwiftUI

struct SoundsToolbar: View {
    @ObservedObject private var player = AmbientPlayer.shared
    @State private var showingVolume = false

    var body: some View {
        HStack(spacing: 12) {
            icon("pianokeys", .piano, "Piano")
            icon("leaf", .nature, "Nature")
            icon("music.note", .ownMusic, "Your music")
        }
        .popover(isPresented: $showingVolume, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Volume").font(.callout)
                Slider(value: $player.volume, in: 0...1).frame(width: 160)
            }
            .padding(14)
        }
    }

    private func icon(_ symbol: String, _ source: AmbientPlayer.Source, _ name: String) -> some View {
        Image(systemName: symbol)
            .foregroundStyle(player.active == source ? Color.accentColor : .secondary)
            .contentShape(Rectangle())
            .onTapGesture(count: 3) { showingVolume = true }
            .onTapGesture(count: 2) { player.next(source) }
            .onTapGesture { player.toggle(source) }
            .help("\(name) — click to play, double-click for next, triple-click for volume")
    }
}
