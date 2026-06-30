// SPDX-License-Identifier: GPL-3.0-only
//  BlockFormatter.swift
//  Pilcrow for macOS
//
//  Line/block-level format toggles (headings, bullet/ordered/checklist lists,
//  blockquote) — the block-level counterpart to MarkdownFormatter's inline
//  wraps. Pure: takes the text of the affected line range and returns the
//  transformed text. Preserves a trailing newline and normalizes mixed-state
//  multi-line selections.

import Foundation

enum BlockFormatter {

    static func toggleBullet(_ block: String) -> String { togglePrefix(block, add: "- ", length: bulletPrefixLength) }
    static func toggleQuote(_ block: String) -> String { togglePrefix(block, add: "> ", length: quotePrefixLength) }

    static func toggleOrdered(_ block: String) -> String {
        mapLines(block) { lines in
            let scope = targetIndices(lines)
            let allHave = scope.allSatisfy { orderedPrefixLength(lines[$0]) != nil }
            var out = lines
            var n = 1
            for i in scope {
                if allHave, let len = orderedPrefixLength(lines[i]) {
                    out[i] = (lines[i] as NSString).substring(from: len)
                } else if !allHave {
                    out[i] = "\(n). " + stripped(lines[i], orderedPrefixLength)
                    n += 1
                }
            }
            return out
        }
    }

    static func setHeading(_ block: String, level: Int) -> String {
        mapLines(block) { lines in
            let scope = targetIndices(lines)
            let allAtLevel = scope.allSatisfy { headingLevel(lines[$0]) == level }
            let marker = String(repeating: "#", count: level) + " "
            var out = lines
            for i in scope {
                var line = lines[i]
                if let lvl = headingLevel(line) { line = (line as NSString).substring(from: lvl + 1) }
                out[i] = allAtLevel ? line : marker + line
            }
            return out
        }
    }

    /// When all target lines are already checklists, flips their check state
    /// (`[ ]`↔`[x]`); otherwise converts each line to an unchecked checklist.
    static func toggleChecklist(_ block: String) -> String {
        mapLines(block) { lines in
            let scope = targetIndices(lines)
            let allChecklist = scope.allSatisfy { checklistPrefixLength(lines[$0]) != nil }
            var out = lines
            for i in scope {
                out[i] = allChecklist ? flipCheck(lines[i]) : "- [ ] " + stripAnyListPrefix(lines[i])
            }
            return out
        }
    }

    // MARK: - Generic prefix toggle (bullet/quote)

    private static func togglePrefix(_ block: String, add: String,
                                     length: (String) -> Int?) -> String {
        mapLines(block) { lines in
            let scope = targetIndices(lines)
            let allHave = scope.allSatisfy { length(lines[$0]) != nil }
            var out = lines
            for i in scope {
                if allHave, let len = length(lines[i]) {
                    out[i] = (lines[i] as NSString).substring(from: len)
                } else if !allHave {
                    out[i] = add + stripped(lines[i], length)   // normalize so mixed selections don't double up
                }
            }
            return out
        }
    }

    // MARK: - Helpers

    /// Splits into logical lines, preserving a trailing newline, then rejoins.
    private static func mapLines(_ block: String, _ transform: ([String]) -> [String]) -> String {
        let trailingNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if trailingNewline { lines.removeLast() }     // drop the phantom empty element
        if lines.isEmpty { lines = [""] }
        return transform(lines).joined(separator: "\n") + (trailingNewline ? "\n" : "")
    }

    /// Non-blank line indices, or all indices when every line is blank.
    private static func targetIndices(_ lines: [String]) -> [Int] {
        let nonBlank = lines.indices.filter { !lines[$0].trimmingCharacters(in: .whitespaces).isEmpty }
        return nonBlank.isEmpty ? Array(lines.indices) : nonBlank
    }

    private static func stripped(_ line: String, _ length: (String) -> Int?) -> String {
        if let len = length(line) { return (line as NSString).substring(from: len) }
        return line
    }

    private static func stripAnyListPrefix(_ line: String) -> String {
        for detector in [checklistPrefixLength, orderedPrefixLength, bulletPrefixLength] {
            if let len = detector(line) { return (line as NSString).substring(from: len) }
        }
        return line
    }

    private static func flipCheck(_ line: String) -> String {
        guard let re = try? NSRegularExpression(pattern: #"^(\s*[-*+] \[)([ xX])(\])"#) else { return line }
        let ns = line as NSString
        guard let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return line }
        let r = m.range(at: 2)
        let next = ns.substring(with: r) == " " ? "x" : " "
        let result = NSMutableString(string: line)
        result.replaceCharacters(in: r, with: next)
        return result as String
    }

    // MARK: - Prefix detectors (matched length in UTF-16 units, or nil)

    private static func bulletPrefixLength(_ line: String) -> Int? {
        matchLength(#"^\s*[-*+] (?!\[[ xX]\])"#, line)
    }
    private static func quotePrefixLength(_ line: String) -> Int? {
        matchLength(#"^\s*> "#, line)
    }
    private static func checklistPrefixLength(_ line: String) -> Int? {
        matchLength(#"^\s*[-*+] \[[ xX]\] "#, line)
    }
    private static func orderedPrefixLength(_ line: String) -> Int? {
        matchLength(#"^\s*\d+[.)] "#, line)
    }
    private static func headingLevel(_ line: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: #"^(#{1,6}) "#),
              let m = re.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
        else { return nil }
        let g = m.range(at: 1)
        return g.location != NSNotFound ? g.length : nil
    }
    private static func matchLength(_ pattern: String, _ line: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
        else { return nil }
        return m.range.length
    }
}
