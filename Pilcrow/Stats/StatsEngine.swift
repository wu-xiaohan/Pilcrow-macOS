// SPDX-License-Identifier: GPL-3.0-only
//  StatsEngine.swift
//  Pilcrow for macOS
//
//  Port of upstream `apostrophe/stats_counter.py`. Computes characters, words,
//  sentences, paragraphs and reading time, after stripping Markdown markup so
//  delimiters don't inflate the counts.

import Foundation

struct ReadingTime: Equatable {
    var hours = 0
    var minutes = 0
    var seconds = 0
}

struct DocumentStats: Equatable {
    var characters = 0
    var words = 0
    var sentences = 0
    var paragraphs = 0
    var readingTime = ReadingTime()

    static let empty = DocumentStats()
}

enum StatsEngine {

    // Any character except newlines and subsequent spaces.
    private static let charactersRE =
        try! NSRegularExpression(pattern: #"[^\s]|(?:[^\S\n](?!\s))"#)

    // Asian letters / symbols / hieroglyphs, plus sequences of word characters
    // optionally containing non-word characters in-between. (ICU \u escapes,
    // matching upstream's [぀-￿].)
    private static let wordsRE =
        try! NSRegularExpression(pattern: #"[぀-￿]|(?:\w+\S?\w*)+"#)

    // Sentence-ending punctuation across many scripts.
    private static let sentencesRE =
        try! NSRegularExpression(pattern: #"[^\n][.。।෴۔።?՞;⸮؟？፧꘏⳺⳻⁇﹖⁈⁉‽!﹗！՜߹႟᥄\n]+"#)

    // Paragraphs: runs separated by at least two newlines.
    private static let paragraphsRE =
        try! NSRegularExpression(pattern: #"(?:[^\n]+\n?)+(?=\n{2,}|\Z)"#)

    // Patterns whose match is replaced by its "text" capture (order matters).
    private static let replacePatterns: [NSRegularExpression] = [
        MarkdownPatterns.boldItalic, MarkdownPatterns.italicAsterisk,
        MarkdownPatterns.italicUnderscore, MarkdownPatterns.bold,
        MarkdownPatterns.strikethrough, MarkdownPatterns.image,
        MarkdownPatterns.link, MarkdownPatterns.linkAlt, MarkdownPatterns.list,
        MarkdownPatterns.orderedList, MarkdownPatterns.blockQuote,
        MarkdownPatterns.header, MarkdownPatterns.headerUnder,
        MarkdownPatterns.codeBlock, MarkdownPatterns.table, MarkdownPatterns.math,
        MarkdownPatterns.footnoteID, MarkdownPatterns.footnote,
    ]

    // Patterns whose match is removed entirely.
    private static let removePatterns: [NSRegularExpression] = [
        MarkdownPatterns.horizontalRule
    ]

    static func compute(_ text: String) -> DocumentStats {
        let stripped = stripMarkup(text)

        let characters = matchCount(charactersRE, in: stripped)
        let words = matchCount(wordsRE, in: stripped)
        let sentences = matchCount(sentencesRE, in: stripped)
        let paragraphs = matchCount(paragraphsRE, in: stripped)

        // read_time = words / 200 wpm.
        let totalSeconds = Int(Double(words) / 200.0 * 60.0)
        let reading = ReadingTime(hours: totalSeconds / 3600,
                                  minutes: (totalSeconds % 3600) / 60,
                                  seconds: totalSeconds % 60)

        return DocumentStats(characters: characters, words: words,
                             sentences: sentences, paragraphs: paragraphs,
                             readingTime: reading)
    }

    // MARK: - Helpers

    private static func stripMarkup(_ text: String) -> String {
        var s = text
        for re in replacePatterns { s = replacingMatches(re, in: s, withGroupNamed: "text") }
        for re in removePatterns { s = replacingMatches(re, in: s, withGroupNamed: nil) }
        return s
    }

    /// Replaces every non-overlapping match with the contents of its named group
    /// (or "" when `name` is nil), mirroring Python's `re.sub(r"\g<text>", …)`.
    private static func replacingMatches(_ re: NSRegularExpression,
                                        in text: String,
                                        withGroupNamed name: String?) -> String {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let matches = re.matches(in: text, range: full)
        guard !matches.isEmpty else { return text }

        let result = NSMutableString(string: text)
        for m in matches.reversed() {
            var replacement = ""
            if let name {
                let g = m.range(withName: name)
                if g.location != NSNotFound { replacement = ns.substring(with: g) }
            }
            result.replaceCharacters(in: m.range, with: replacement)
        }
        return result as String
    }

    private static func matchCount(_ re: NSRegularExpression, in text: String) -> Int {
        let ns = text as NSString
        return re.numberOfMatches(in: text, range: NSRange(location: 0, length: ns.length))
    }
}
