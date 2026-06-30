// SPDX-License-Identifier: GPL-3.0-only
//  ListContinuation.swift
//  Pilcrow for macOS
//
//  Computes the marker to insert when Return is pressed on a list line
//  (bullet / checklist / ordered), mirroring the list-continuation behavior of
//  text_view_format_inserter. Pure & testable.

import Foundation

enum ListContinuation {
    struct Result {
        let marker: String     // text to start the next item with
        let isEmptyItem: Bool  // current item has no content → terminate the list
    }

    static func next(for line: String) -> Result? {
        if let m = match(MarkdownPatterns.orderedList, line) {
            let indent = group(m, "indent", line)
            let number = Int(group(m, "number", line)) ?? 0
            let delimiter = group(m, "delimiter", line)
            let empty = group(m, "text", line).trimmingCharacters(in: .whitespaces).isEmpty
            return Result(marker: "\(indent)\(number + 1)\(delimiter) ", isEmptyItem: empty)
        }
        if let m = match(MarkdownPatterns.checklist, line) {
            let indent = group(m, "indent", line)
            let symbol = group(m, "symbol", line)
            let empty = group(m, "text", line).trimmingCharacters(in: .whitespaces).isEmpty
            return Result(marker: "\(indent)\(symbol) [ ] ", isEmptyItem: empty)
        }
        if let m = match(MarkdownPatterns.list, line) {
            let indent = group(m, "indent", line)
            let symbol = group(m, "symbol", line)
            let empty = group(m, "text", line).trimmingCharacters(in: .whitespaces).isEmpty
            return Result(marker: "\(indent)\(symbol) ", isEmptyItem: empty)
        }
        return nil
    }

    private static func match(_ re: NSRegularExpression, _ s: String) -> NSTextCheckingResult? {
        re.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length))
    }
    private static func group(_ m: NSTextCheckingResult, _ name: String, _ s: String) -> String {
        let r = m.range(withName: name)
        guard r.location != NSNotFound else { return "" }
        return (s as NSString).substring(with: r)
    }
}
