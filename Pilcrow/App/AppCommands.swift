// SPDX-License-Identifier: GPL-3.0-only
//  AppCommands.swift
//  Pilcrow for macOS
//
//  Native menu-bar commands routed to the focused PilcrowTextView.

import SwiftUI
import AppKit

enum Cmd {
    static func send(_ selector: Selector) { NSApp.sendAction(selector, to: nil, from: nil) }
}

enum FindAction {
    static func perform(_ action: NSTextFinder.Action) {
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        NSApp.sendAction(#selector(NSTextView.performTextFinderAction(_:)), to: nil, from: sender)
    }
}

struct FormatCommands: Commands {
    var body: some Commands {
        CommandMenu("Format") {
            Button("Bold") { Cmd.send(#selector(PilcrowTextView.toggleBold(_:))) }
                .keyboardShortcut("b", modifiers: .command)
            Button("Italic") { Cmd.send(#selector(PilcrowTextView.toggleItalic(_:))) }
                .keyboardShortcut("i", modifiers: .command)
            Button("Strikethrough") { Cmd.send(#selector(PilcrowTextView.toggleStrikethrough(_:))) }
                .keyboardShortcut("x", modifiers: [.command, .shift])
            Button("Inline Code") { Cmd.send(#selector(PilcrowTextView.toggleInlineCode(_:))) }
                .keyboardShortcut("c", modifiers: [.command, .shift])

            Divider()

            Button("Link") { Cmd.send(#selector(PilcrowTextView.insertLink(_:))) }
                .keyboardShortcut("k", modifiers: .command)
            Button("Image…") { Cmd.send(#selector(PilcrowTextView.insertImage(_:))) }
                .keyboardShortcut("k", modifiers: [.command, .shift])

            Divider()

            Menu("Heading") {
                Button("Heading 1") { Cmd.send(#selector(PilcrowTextView.setHeading1(_:))) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Heading 2") { Cmd.send(#selector(PilcrowTextView.setHeading2(_:))) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Heading 3") { Cmd.send(#selector(PilcrowTextView.setHeading3(_:))) }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Heading 4") { Cmd.send(#selector(PilcrowTextView.setHeading4(_:))) }
                    .keyboardShortcut("4", modifiers: .command)
                Button("Heading 5") { Cmd.send(#selector(PilcrowTextView.setHeading5(_:))) }
                    .keyboardShortcut("5", modifiers: .command)
                Button("Heading 6") { Cmd.send(#selector(PilcrowTextView.setHeading6(_:))) }
                    .keyboardShortcut("6", modifiers: .command)
            }

            Divider()

            Button("Bullet List") { Cmd.send(#selector(PilcrowTextView.toggleBulletList(_:))) }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            Button("Numbered List") { Cmd.send(#selector(PilcrowTextView.toggleOrderedList(_:))) }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("Checklist") { Cmd.send(#selector(PilcrowTextView.toggleChecklist(_:))) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Blockquote") { Cmd.send(#selector(PilcrowTextView.toggleBlockquote(_:))) }
                .keyboardShortcut("b", modifiers: [.command, .shift])

            Divider()

            Button("Code Block") { Cmd.send(#selector(PilcrowTextView.insertCodeBlock(_:))) }
                .keyboardShortcut("c", modifiers: [.command, .option])
            Button("Horizontal Rule") { Cmd.send(#selector(PilcrowTextView.insertHorizontalRule(_:))) }
                .keyboardShortcut("r", modifiers: [.command, .control])
        }
    }
}

struct ViewCommands: Commands {
    @AppStorage(SettingsKey.focusMode) private var focusMode = false
    @AppStorage(SettingsKey.previewActive) private var previewActive = false
    @AppStorage(SettingsKey.hemingwayMode) private var hemingwayMode = false

    var body: some Commands {
        // Attach to the system View menu (avoids a duplicate top-level "View").
        CommandGroup(after: .toolbar) {
            Toggle("Focus Mode", isOn: $focusMode)
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Toggle("Show Preview", isOn: $previewActive)
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Divider()
            Toggle("Hemingway Mode", isOn: $hemingwayMode)
                .keyboardShortcut("h", modifiers: [.command, .control])
        }
    }
}

struct FindCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Section {
                Button("Find…") { FindAction.perform(.showFindInterface) }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Find and Replace…") { FindAction.perform(.showReplaceInterface) }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                Button("Find Next") { FindAction.perform(.nextMatch) }
                    .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") { FindAction.perform(.previousMatch) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }
    }
}
