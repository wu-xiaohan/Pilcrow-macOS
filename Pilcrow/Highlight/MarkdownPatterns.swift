// SPDX-License-Identifier: GPL-3.0-only
//  MarkdownPatterns.swift
//  Pilcrow for macOS
//
//  Direct port of upstream Apostrophe's `apostrophe/markup_regex.py`
//  (Python `regex` module) to ICU / NSRegularExpression.
//
//  Porting notes (Python `regex`  →  ICU):
//    (?P<name>…)   →  (?<name>…)
//    (?P=name)     →  \k<name>
//    \p{L} \p{N}   →  supported as-is
//    (?>…)         →  atomic groups, supported as-is
//    re.VERBOSE    →  .allowCommentsAndWhitespace
//    re.DOTALL     →  .dotMatchesLineSeparators
//    re.MULTILINE  →  .anchorsMatchLines
//    re.I          →  .caseInsensitive
//
//  IMPORTANT ICU divergence from Python's re.VERBOSE: ICU's comments/whitespace
//  mode ignores spaces *inside* character classes too. So Python's `[ ]` (a
//  literal-space class) becomes an empty/invalid class in ICU. Every literal
//  space that must MATCH is therefore written as `\x20` (which ICU honors inside
//  and outside classes alike).
//
//  Swift raw strings (#"""…"""#) mirror Python raw strings: `\n`, `\\`, `\1`,
//  `\k<…>`, `\x20` all reach the regex engine verbatim. (`\#` is the raw-string
//  escape introducer, so the header uses `[#]` rather than `\#`.)

import Foundation

/// Markdown syntax categories (one per upstream regex).
enum MarkdownSyntax: String, CaseIterable {
    case boldItalic, bold, italicAsterisk, italicUnderscore, strikethrough
    case code, codeBlock
    case header, headerUnder, horizontalRule
    case list, checklist, orderedList, blockQuote
    case link, linkAlt, url, image
    case math, table
    case footnoteID, footnote, frontmatter
}

/// A compiled pattern plus the metadata the highlighter needs.
struct MarkdownPattern {
    let syntax: MarkdownSyntax
    let regex: NSRegularExpression
    /// Block constructs span multiple lines and need a widened rescan window
    /// (not a single edited paragraph).
    let isBlock: Bool
}

enum MarkdownPatterns {

    private static func re(_ pattern: String,
                          _ options: NSRegularExpression.Options = []) -> NSRegularExpression {
        do { return try NSRegularExpression(pattern: pattern, options: options) }
        catch { fatalError("Invalid markdown regex \(error):\n\(pattern)") }
    }

    private static let verbose: NSRegularExpression.Options = [.allowCommentsAndWhitespace]

    // MARK: - Emphasis

    static let italicAsterisk = re(#"""
        (?<![\\*])      # Can't start with \ or an extra *
        \*              # Start with *
        (?<text>        # Text content group
            (?:         # either
                [^\s*\\]    # a single character that is not whitespace, * or backslash
            |           # or
                [^\s*]      # Can't start text with whitespace or *
                .*?
                [^\\*]      # Can't end text with * or \
            )
        )
        \*              # End with *
        (?!\*)          # Can't end with extra *
        """#, verbose)

    static let italicUnderscore = re(#"""
        (?<![\\_\p{L}\p{N}])    # Can't be preceded by \, an extra _ or alphanumerics
        _                       # Start with _
        (?<text>
            (?:
                [^\s_\\]            # a single non-whitespace/_/backslash char
            |
                [^\s_]              # Can't start with whitespace or _
                .*?
                [^\\_]              # Can't end text with _ or \
            )
        )
        _                       # End with _
        (?![\p{L}\p{N}_])       # Can't be followed by alphanumeric or _
        """#, verbose)

    static let bold = re(#"""
        (?<!\\)         # Can't be preceded by \
        (\*\*|__)       # Delimiter start (** or __)
        (?<text>
            (?:
                [^\s_*\\]
            |
                [^\s*]
                .*?
                [^\\]
            )
        )
        \1              # Closing delimiter matches opening
        """#, verbose)

    static let boldItalic = re(#"""
        (?<!\\)
        ((\*\*|__)([*_])|([*_])(\*\*|__))
        (?<text>
            (?:
                [^\s_*\\]
            |
                [^\s*]
                .*?
                [^\\]
            )
        )
        (?:\5\4|\3\2)
        """#, verbose)

    static let strikethrough = re(#"""
        (?<!\\)
        ~~
        (?<text>
            (?:
                [^\s_*\\]
            |
                [^\s*]
                .*?
                [^\s\\]
            )
        )
        ~~
        """#, verbose)

    static let code = re(#"""
        (?<!`)
        (?<ticks>`+)
        (?!`)
        (?<text>.+?)
        (?<!`)
        \k<ticks>
        (?!`)
        """#, verbose)

    // MARK: - Links / images / URLs

    static let link = re(#"""
        \[(?<text>.*?)\]              # [link text]
        \(                           # opening parenthesis
            (?<url>.+?)              # URL
            (?:\x20\"(?<title>.+)\")? # optional title
        \)
        """#, verbose)

    static let linkAlt = re(#"""
        <(?<text>(?<url>((https?|ftp):[^'">\s]+)))>
        """#, verbose)

    // NOTE: upstream's URL regex is genuinely broken (a character class that
    // accidentally swallows the scheme), so this is re-derived rather than ported.
    static let url = re(#"(?<url>(?:https?|ftp)://[\w\-._~:/?#\[\]@!$&'()*+,;=%]+)"#,
                        [.caseInsensitive])

    static let image = re(#"""
        !\[(?<text>.*?)\]
        \(
            (?<url>.+?)
            (?:\x20\"(?<title>.+)\")?
        \)
        """#, verbose)

    // MARK: - Blocks

    static let horizontalRule = re(#"""
        (?:^|\n{2,})\x20{0,3}            # at most 3 leading spaces
        (?<symbols>
            (-\x20{0,2}){3,} |          # 3+ hyphens, up to 2 spaces between
            (_\x20{0,2}){3,} |          # idem with underscores
            (\*\x20{0,2}){3,}           # idem with asterisks
        )
        [\x20\t]*                       # optional trailing spaces/tabs
        (?:\n{2,}|$)                    # blank line or end of document
        """#, verbose)

    static let list = re(#"""
        (?:^|\n)                          # start of line or newline
        (?<content>
            (?<indent>(?:\t|\x20{2})*)    # tab or 2 spaces, any number of times
            (?<symbol>(?:[\-*+]))         # bullet: - * or +
            \x20(?!\[[xX\x20]\])          # don't match a checklist marker
            (?:\t|\x20{2})*
            (?<text>
                .+
            )?
        )
        """#, verbose)

    static let checklist = re(#"""
        (?:^|\n)
        (?<content>
            (?<indent>(?:\t|\x20{2})*)
            (?<symbol>(?:[\-*+]))
            \x20\[(?<check>(?:[xX\x20]))\]\x20  # [ ] / [x] / [X]
            (?:\t|\x20{4})*
            (?<text>
                .+
            )?
        )
        """#, verbose)

    static let orderedList = re(#"""
        (?:^|\n)
        (?<content>
            (?<indent>(?>\t|\x20{2})*)
            (?<prefix>
                (?:
                    (?<number>\d+)        # a number
                |
                    [a-z]+                # or a letter
                )
                (?<delimiter>[.)])        # . or ) delimiter
            )
            [\x20\t]*
            (?<text>
                .+
            )?
        )
        """#, verbose)

    static let blockQuote = re(#"""
        ^\x20{0,3}(?:>\x20?)+(?<text>.+)
        """#, [.allowCommentsAndWhitespace, .anchorsMatchLines])

    static let header = re(#"""
        ^                       # start of line
        (?<level>\x23{1,6})\x20 # 1 to 6 hashes then a space
        (?<text>[^\n]+)         # text until newline
        """#, [.allowCommentsAndWhitespace, .anchorsMatchLines])

    static let headerUnder = re(#"""
        ^                       # start of line
        (?<text>.+)[\x20\t]*    # text (excluding trailing whitespace)
        \n
        [=-]+[\x20\t]*          # === or --- underline
        (?:\n)
        """#, [.allowCommentsAndWhitespace, .anchorsMatchLines])

    static let codeBlock = re(#"""
        ^\x20{0,3}
        (?<block>
            ([`~]{3})           # ``` or ~~~
            (?<text>.+?)
            (?<!\x20)\x20{0,3}  # no more than three spaces before the close
            \2                  # same fence as the open
        )
        (?:\s+?$|$)
        """#, [.allowCommentsAndWhitespace, .dotMatchesLineSeparators, .anchorsMatchLines])

    // Upstream uses only re.S here (so `^` anchors to start of string).
    static let table = re(#"^[\-+]{5,}\n(?<text>.+?)\n[\-+]{5,}\n"#,
                          [.dotMatchesLineSeparators])

    static let math = re(#"""
        ([$]{1,2})              # $ or $$
        (?<text>
            [^`\\\x20]{1,2}     # one/two chars: not `, \ or space
            |
            [^`\x20].+?[^`\\\x20]) # else: can't start with `/space, can't end with `,\ or space
        \1
        """#, [.allowCommentsAndWhitespace, .dotMatchesLineSeparators, .anchorsMatchLines])

    static let footnoteID = re(#"""
        (?<text>[^\s]+)         # any text without spaces
        \[\^(?<id>[^\s]+)\]     # [^id_without_spaces]
        """#, verbose)

    static let footnote = re(#"""
        \x20{0,3}
        \[\^(?<id>[^\s]+)\]:
        \x20{0,7}
        (?<text>
            (?:
                [^\n]+
            |
                \n+(?=(?:\t|\x20{4}))
            )+
        )
        (?:\n+|$)
        """#, [.allowCommentsAndWhitespace, .anchorsMatchLines])

    // Upstream uses only re.DOTALL (so `^` anchors to start of string).
    static let frontmatter = re(#"^(?:---)\n(?<text>.+?)\n(?:---|\.{3})"#,
                                [.dotMatchesLineSeparators])

    // MARK: - Ordered list for highlighting / stripping

    /// All patterns, ordered for highlight application. Block constructs first so
    /// inline emphasis layered on top wins where ranges overlap.
    static let all: [MarkdownPattern] = [
        MarkdownPattern(syntax: .codeBlock,      regex: codeBlock,      isBlock: true),
        MarkdownPattern(syntax: .frontmatter,    regex: frontmatter,    isBlock: true),
        MarkdownPattern(syntax: .table,          regex: table,          isBlock: true),
        MarkdownPattern(syntax: .header,         regex: header,         isBlock: true),
        MarkdownPattern(syntax: .headerUnder,    regex: headerUnder,    isBlock: true),
        MarkdownPattern(syntax: .horizontalRule, regex: horizontalRule, isBlock: true),
        MarkdownPattern(syntax: .blockQuote,     regex: blockQuote,     isBlock: true),
        MarkdownPattern(syntax: .list,           regex: list,           isBlock: true),
        MarkdownPattern(syntax: .orderedList,    regex: orderedList,    isBlock: true),
        MarkdownPattern(syntax: .checklist,      regex: checklist,      isBlock: true),
        MarkdownPattern(syntax: .footnote,       regex: footnote,       isBlock: true),
        MarkdownPattern(syntax: .image,          regex: image,          isBlock: false),
        MarkdownPattern(syntax: .link,           regex: link,           isBlock: false),
        MarkdownPattern(syntax: .linkAlt,        regex: linkAlt,        isBlock: false),
        MarkdownPattern(syntax: .url,            regex: url,            isBlock: false),
        MarkdownPattern(syntax: .boldItalic,     regex: boldItalic,     isBlock: false),
        MarkdownPattern(syntax: .bold,           regex: bold,           isBlock: false),
        MarkdownPattern(syntax: .italicAsterisk, regex: italicAsterisk, isBlock: false),
        MarkdownPattern(syntax: .italicUnderscore, regex: italicUnderscore, isBlock: false),
        MarkdownPattern(syntax: .strikethrough,  regex: strikethrough,  isBlock: false),
        MarkdownPattern(syntax: .code,           regex: code,           isBlock: false),
        MarkdownPattern(syntax: .math,           regex: math,           isBlock: false),
        MarkdownPattern(syntax: .footnoteID,     regex: footnoteID,     isBlock: false),
    ]
}
