// SPDX-License-Identifier: GPL-3.0-only
//  ListIndenter.swift
//  Pilcrow for macOS
//
//  Tab / Shift-Tab indentation for list lines (2-space unit, matching the list
//  highlight regex `(?:\t|[ ]{2})*`). Non-list lines are left to the default
//  tab behavior. Pure & testable.

import Foundation

enum ListIndenter {
    static let unit = "  "   // two spaces

    static func isListLine(_ line: String) -> Bool {
        matches(#"^\s*([-*+]|\d+[.)]) "#, line)
    }

    static func blockHasListLine(_ block: String) -> Bool {
        block.components(separatedBy: "\n").contains(where: isListLine)
    }

    static func indent(_ block: String) -> String {
        transform(block) { unit + $0 }
    }

    static func outdent(_ block: String) -> String {
        transform(block) { line in
            if line.hasPrefix(unit) { return String(line.dropFirst(unit.count)) }
            if line.hasPrefix("\t") { return String(line.dropFirst()) }
            if line.hasPrefix(" ") { return String(line.dropFirst()) }
            return line
        }
    }

    private static func transform(_ block: String, _ f: (String) -> String) -> String {
        block.components(separatedBy: "\n").map { line in
            isListLine(line) ? f(line) : line
        }.joined(separator: "\n")
    }

    private static func matches(_ pattern: String, _ s: String) -> Bool {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return false }
        return re.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
    }
}
