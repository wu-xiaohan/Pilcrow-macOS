// SPDX-License-Identifier: GPL-3.0-only
//  MarkdownFormatter.swift
//  Pilcrow for macOS
//
//  Wrapping-format toggles (bold/italic/strikethrough/code), a port of
//  text_view_format_inserter.__wrap. Pure & testable: given the text and
//  selection, returns the edit to apply.

import Foundation

struct FormatEdit {
    let range: NSRange         // range to replace
    let replacement: String
    let selection: NSRange     // selection after applying
}

enum MarkdownFormatter {
    static func wrap(_ text: NSString, range: NSRange, marker: String, placeholder: String) -> FormatEdit {
        let m = (marker as NSString).length

        // No selection: insert markers + placeholder, select the placeholder.
        guard range.length > 0 else {
            let replacement = marker + placeholder + marker
            return FormatEdit(range: range, replacement: replacement,
                              selection: NSRange(location: range.location + m,
                                                 length: (placeholder as NSString).length))
        }

        // Unwrap when the markers sit just outside the selection.
        if range.location >= m, range.location + range.length + m <= text.length {
            let ext = NSRange(location: range.location - m, length: range.length + 2 * m)
            let extText = text.substring(with: ext) as NSString
            if extText.hasPrefix(marker), extText.hasSuffix(marker) {
                let inner = extText.substring(with: NSRange(location: m, length: extText.length - 2 * m))
                return FormatEdit(range: ext, replacement: inner,
                                  selection: NSRange(location: ext.location, length: (inner as NSString).length))
            }
        }

        // Unwrap when the selection itself includes the markers.
        let selText = text.substring(with: range) as NSString
        if selText.length >= 2 * m, selText.hasPrefix(marker), selText.hasSuffix(marker) {
            let inner = selText.substring(with: NSRange(location: m, length: selText.length - 2 * m))
            return FormatEdit(range: range, replacement: inner,
                              selection: NSRange(location: range.location, length: (inner as NSString).length))
        }

        // Otherwise wrap the selection, preserving any outer whitespace.
        let core = selText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !core.isEmpty else {
            return FormatEdit(range: range, replacement: marker + (selText as String) + marker,
                              selection: NSRange(location: range.location + m, length: selText.length))
        }
        let coreRange = selText.range(of: core)
        let lead = selText.substring(to: coreRange.location)
        let trail = selText.substring(from: coreRange.location + coreRange.length)
        return FormatEdit(range: range, replacement: lead + marker + core + marker + trail,
                          selection: NSRange(location: range.location + (lead as NSString).length + m,
                                             length: (core as NSString).length))
    }

    /// Inserts a `[text](url)` link, mirroring insert_link: a selected URL
    /// becomes the target (placeholder text selected); other selected text
    /// becomes the label (url placeholder selected); no selection inserts both.
    static func link(_ text: NSString, range: NSRange) -> FormatEdit {
        let url = "https://www.example.com"
        let label = "link text"

        if range.length > 0 {
            let selected = text.substring(with: range)
            if looksLikeURL(selected) {
                // Selected text is the URL → it's the target; select the label.
                return FormatEdit(range: range, replacement: "[\(label)](\(selected))",
                                  selection: NSRange(location: range.location + 1, length: (label as NSString).length))
            }
            // Selected text is the label → select the URL placeholder.
            let replacement = "[\(selected)](\(url))"
            let start = range.location + 1 + (selected as NSString).length + 2   // after "]("
            return FormatEdit(range: range, replacement: replacement,
                              selection: NSRange(location: start, length: (url as NSString).length))
        }

        // No selection → insert both, select the URL placeholder.
        let replacement = "[\(label)](\(url))"
        let start = range.location + 1 + (label as NSString).length + 2
        return FormatEdit(range: range, replacement: replacement,
                          selection: NSRange(location: start, length: (url as NSString).length))
    }

    static func looksLikeURL(_ s: String) -> Bool {
        s.contains("://") || s.range(of: #"^(https?://|ftp://|www\.|/|\./)"#, options: .regularExpression) != nil
    }
}
