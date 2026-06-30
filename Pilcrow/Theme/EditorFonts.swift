// SPDX-License-Identifier: GPL-3.0-only
//  EditorFonts.swift
//  Pilcrow for macOS
//
//  Resolves the user's per-script font choices (Latin body font + CJK font) to
//  concrete NSFonts. "Default" = the monospace editor face; "System" = system.

import AppKit

enum EditorFonts {
    /// (label shown in the picker, stored value / family name)
    static let latinChoices: [(label: String, value: String)] = [
        ("Default (Mono)", "Default"),
        ("Lora", "Lora"),
        ("Shantell Sans", "Shantell Sans"),
        ("System", "System"),
    ]
    static let cjkChoices: [(label: String, value: String)] = [
        ("Default", "Default"),
        ("Noto Sans SC", "Noto Sans SC"),
        ("Ma Shan Zheng", "Ma Shan Zheng"),
    ]

    /// Latin / body font for the editor.
    static func body(family: String?, size: CGFloat) -> NSFont {
        switch family {
        case nil, "", "Default":
            return NSFont(name: "Fira Mono", size: size)
                ?? NSFont(name: "SFMono-Regular", size: size)
                ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        case "System":
            return .systemFont(ofSize: size)
        default:
            let descriptor = NSFontDescriptor(fontAttributes: [.family: family!])
            return NSFont(descriptor: descriptor, size: size) ?? .systemFont(ofSize: size)
        }
    }

    /// CJK font, or nil to leave the system fallback in place.
    static func cjk(family: String?, size: CGFloat) -> NSFont? {
        switch family {
        case nil, "", "Default", "System":
            return nil
        default:
            let descriptor = NSFontDescriptor(fontAttributes: [.family: family!])
            return NSFont(descriptor: descriptor, size: size)
        }
    }
}
