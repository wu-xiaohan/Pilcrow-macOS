// SPDX-License-Identifier: GPL-3.0-only
//  SettingsView.swift
//  Pilcrow for macOS — Settings scene (opens as a separate window via ⌘, or
//  the toolbar menu's “Preferences…”).

import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.colorScheme) private var colorSchemeRaw = AppColorScheme.system.rawValue
    @AppStorage(SettingsKey.charactersPerLine) private var charactersPerLine = AppDefaults.charactersPerLineDefault
    @AppStorage(SettingsKey.spellcheck) private var spellcheck = true
    @AppStorage(SettingsKey.biggerText) private var biggerText = false
    @AppStorage(SettingsKey.hemingwayMode) private var hemingwayMode = false
    @AppStorage(SettingsKey.bionicReading) private var bionicReading = false
    @AppStorage(SettingsKey.latinFont) private var latinFont = "Default"
    @AppStorage(SettingsKey.cjkFont) private var cjkFont = "Default"
    @ObservedObject private var sounds = AmbientPlayer.shared

    private let lo = Int(AppDefaults.charactersPerLineRange.lowerBound)
    private let hi = Int(AppDefaults.charactersPerLineRange.upperBound)

    // The text field edits a string so partial input (e.g. "8" on the way to
    // "80") isn't clamped mid-keystroke; we parse + clamp only on commit.
    @State private var cplText = ""
    @FocusState private var cplFieldFocused: Bool

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Color scheme", selection: $colorSchemeRaw) {
                    ForEach(AppColorScheme.presets) { scheme in
                        Text(scheme.label).tag(scheme.rawValue)
                    }
                }
                Toggle("Bigger text", isOn: $biggerText)
            }

            Section("Editor") {
                Toggle("Check spelling while typing", isOn: $spellcheck)
                Toggle("Hemingway mode (no deletions)", isOn: $hemingwayMode)
                Toggle("Bionic reading", isOn: $bionicReading)

                LabeledContent("Characters per line") {
                    HStack(spacing: 8) {
                        TextField("", text: $cplText)
                            .frame(width: 56)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .focused($cplFieldFocused)
                            .onSubmit { commitCharactersPerLine() }
                            .onChange(of: cplFieldFocused) { _, focused in
                                if !focused { commitCharactersPerLine() }
                            }
                        Stepper("", value: $charactersPerLine, in: lo...hi)
                            .labelsHidden()
                    }
                }
            }

            Section("Fonts") {
                Picker("Latin font", selection: $latinFont) {
                    ForEach(EditorFonts.latinChoices, id: \.value) { Text($0.label).tag($0.value) }
                }
                Picker("CJK font", selection: $cjkFont) {
                    ForEach(EditorFonts.cjkChoices, id: \.value) { Text($0.label).tag($0.value) }
                }
            }

            Section("Background Sounds") {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $sounds.volume, in: 0...1)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
                Button("Add Music…") { sounds.addMusic() }

                DisclosureGroup("Your music (\(sounds.userTracks.count))") {
                    if sounds.userTracks.isEmpty {
                        Text("No songs added yet.")
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            VStack(spacing: 2) {
                                ForEach(sounds.userTracks, id: \.self) { url in
                                    HStack {
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .lineLimit(1).truncationMode(.middle)
                                        Spacer()
                                        Button(role: .destructive) {
                                            sounds.removeMusic(url)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 160)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .onAppear { cplText = String(charactersPerLine) }
        // Reflect Stepper / external changes in the text field, but never while
        // the user is mid-edit (that's what made typing impossible before).
        .onChange(of: charactersPerLine) { _, value in
            if !cplFieldFocused { cplText = String(value) }
        }
    }

    private func commitCharactersPerLine() {
        let parsed = Int(cplText.trimmingCharacters(in: .whitespaces)) ?? charactersPerLine
        charactersPerLine = min(hi, max(lo, parsed))
        cplText = String(charactersPerLine)
    }
}
