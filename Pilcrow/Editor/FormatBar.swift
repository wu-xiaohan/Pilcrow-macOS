// SPDX-License-Identifier: GPL-3.0-only
//  FormatBar.swift
//  Pilcrow for macOS
//
//  Bottom-left collapsible formatting toolbar (Apostrophe-style): a chevron that
//  unfolds a row of icon buttons. Actions route to the focused editor via the
//  same selectors as the Format menu.

import SwiftUI
import AppKit

struct FormatBar: View {
    @State private var expanded = false

    private struct Item { let icon: String; let help: String; let selector: Selector }
    private let items: [Item] = [
        .init(icon: "bold", help: "Bold (⌘B)", selector: #selector(PilcrowTextView.toggleBold(_:))),
        .init(icon: "italic", help: "Italic (⌘I)", selector: #selector(PilcrowTextView.toggleItalic(_:))),
        .init(icon: "strikethrough", help: "Strikethrough (⇧⌘X)", selector: #selector(PilcrowTextView.toggleStrikethrough(_:))),
        .init(icon: "number", help: "Heading (⌘1)", selector: #selector(PilcrowTextView.setHeading1(_:))),
        .init(icon: "list.bullet", help: "Bullet List (⇧⌘U)", selector: #selector(PilcrowTextView.toggleBulletList(_:))),
        .init(icon: "list.number", help: "Numbered List (⇧⌘O)", selector: #selector(PilcrowTextView.toggleOrderedList(_:))),
        .init(icon: "checklist", help: "Checklist (⇧⌘L)", selector: #selector(PilcrowTextView.toggleChecklist(_:))),
        .init(icon: "text.quote", help: "Blockquote (⇧⌘B)", selector: #selector(PilcrowTextView.toggleBlockquote(_:))),
        .init(icon: "curlybraces", help: "Code Block (⌥⌘C)", selector: #selector(PilcrowTextView.insertCodeBlock(_:))),
        .init(icon: "link", help: "Link (⌘K)", selector: #selector(PilcrowTextView.insertLink(_:))),
    ]

    var body: some View {
        HStack(spacing: 20) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "chevron.left" : "chevron.right")
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help(expanded ? "Hide formatting" : "Show formatting")

            if expanded {
                Group {
                    ForEach(items.indices, id: \.self) { i in
                        Button { Cmd.send(items[i].selector) } label: {
                            Image(systemName: items[i].icon)
                        }
                        .buttonStyle(.borderless)
                        .focusable(false)
                        .help(items[i].help)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .font(.system(size: 26))
        .foregroundStyle(.secondary)
    }
}

/// The bottom bar: collapsible format toolbar on the left, stats on the right,
/// painted with the editor background (no contrasting stripe).
struct BottomBar: View {
    let stats: DocumentStats
    let background: Color

    var body: some View {
        HStack(spacing: 0) {
            FormatBar()
            Spacer(minLength: 12)
            StatsBar(stats: stats)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(background)
    }
}
