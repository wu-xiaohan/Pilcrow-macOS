// SPDX-License-Identifier: GPL-3.0-only
//  PilcrowApp.swift
//  Pilcrow for macOS — a native rewrite of the GNOME Apostrophe editor.

import SwiftUI

@main
struct PilcrowApp: App {

    init() {
        AppDefaults.register()
        BundledFonts.register()
    }

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            EditorView(text: file.$document.text, fileURL: file.fileURL)
        }
        .commands {
            FormatCommands()
            ViewCommands()
            FindCommands()
            CommandGroup(replacing: .help) {
                Link("Pilcrow Help",
                     destination: URL(string: "https://gitlab.gnome.org/World/apostrophe")!)
            }
        }

        Settings {
            SettingsView()
        }

        Window("Pick Your Color", id: "pick-color") {
            PickColorView()
        }
        .windowResizability(.contentSize)
    }
}
