// SPDX-License-Identifier: GPL-3.0-only
//  PickColorView.swift
//  Pilcrow for macOS
//
//  "Pick Your Color" window: a free-form custom background plus the two theme
//  favourites pinned to the main menu.

import SwiftUI
import AppKit

struct PickColorView: View {
    @AppStorage(SettingsKey.colorScheme) private var colorSchemeRaw = AppColorScheme.sepia.rawValue
    @AppStorage(SettingsKey.customBackground) private var customBackground = "#FBF1E6"
    @AppStorage(SettingsKey.favouriteThemes) private var favouriteThemes = "sepia,sage"

    var body: some View {
        Form {
            Section("Custom color") {
                ColorPicker("Background", selection: customColor, supportsOpacity: false)
                Text("Picking a color switches the theme to Custom; the text color adapts automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Pinned favourites") {
                Picker("Favourite 1", selection: favourite(0)) {
                    ForEach(AppColorScheme.presets) { Text($0.label).tag($0.rawValue) }
                }
                Picker("Favourite 2", selection: favourite(1)) {
                    ForEach(AppColorScheme.presets) { Text($0.label).tag($0.rawValue) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 280)
    }

    private var customColor: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: customBackground) ?? .white) },
            set: { newValue in
                customBackground = NSColor(newValue).usingColorSpace(.sRGB)?.cssHex ?? "#FBF1E6"
                colorSchemeRaw = AppColorScheme.custom.rawValue
            })
    }

    private func favourite(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                let parts = favouriteThemes.split(separator: ",").map(String.init)
                return index < parts.count ? parts[index] : AppColorScheme.sepia.rawValue
            },
            set: { newValue in
                var parts = favouriteThemes.split(separator: ",").map(String.init)
                while parts.count < 2 { parts.append(AppColorScheme.sepia.rawValue) }
                parts[index] = newValue
                favouriteThemes = parts.prefix(2).joined(separator: ",")
            })
    }
}
