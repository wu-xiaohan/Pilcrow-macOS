// SPDX-License-Identifier: GPL-3.0-only
//  HelpDocs.swift
//  Pilcrow for macOS
//
//  Opens the bundled help documents (tutorial.md / instruction.md) in the editor.

import Foundation

enum HelpDocs {
    static let tutorial = "tutorial"
    static let instruction = "instruction"

    /// A writable temp copy of a bundled `.md` doc, so opening it in the editor
    /// doesn't try to write back to the read-only app bundle. Returns nil if the
    /// resource isn't bundled.
    static func openableURL(_ resource: String) -> URL? {
        guard let bundled = Bundle.main.url(forResource: resource, withExtension: "md") else { return nil }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(resource).md")
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: bundled, to: dest)
            return dest
        } catch {
            return bundled   // fall back to the bundle copy (read-only)
        }
    }
}
