// SPDX-License-Identifier: GPL-3.0-only
//  SyntaxHighlighter.swift
//  Pilcrow for macOS
//
//  Applies live Markdown highlighting to an NSTextStorage by running the ported
//  MarkdownPatterns and setting text attributes — mirroring upstream's
//  text_view_markup_handler.py (which tags a GtkSource buffer). Delimiters are
//  dimmed; headings scale and bold; code uses a monospaced face; etc.

import AppKit

final class SyntaxHighlighter {
    var theme: EditorTheme
    var baseFont: NSFont
    /// Bionic reading: bold the leading portion of each word to guide the eye.
    var bionic = false
    /// CJK font family applied to CJK runs (nil = leave system fallback).
    var cjkFamily: String?

    init(theme: EditorTheme, baseFont: NSFont) {
        self.theme = theme
        self.baseFont = baseFont
    }

    /// Re-highlights the whole storage. (Block patterns need whole-document
    /// context; documents are typically small, and callers debounce.)
    func highlight(_ storage: NSTextStorage) {
        let text = storage.string
        let full = NSRange(location: 0, length: (text as NSString).length)
        guard full.length > 0 else { return }

        storage.beginEditing()
        storage.setAttributes([.font: baseFont, .foregroundColor: theme.foreground], range: full)

        for pattern in MarkdownPatterns.all {
            pattern.regex.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
                guard let match else { return }
                self.style(pattern.syntax, match, storage)
            }
        }

        if cjkFamily != nil { applyCJK(storage, text: text, range: full) }
        if bionic { applyBionic(storage, text: text, range: full) }

        storage.endEditing()
    }

    private static let cjkRE = try! NSRegularExpression(pattern: #"[⺀-鿿豈-﫿＀-￯　-〿]+"#)

    /// Applies the chosen CJK font to CJK runs (respecting each run's size).
    private func applyCJK(_ storage: NSTextStorage, text: String, range: NSRange) {
        Self.cjkRE.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match else { return }
            let size = (storage.attribute(.font, at: match.range.location, effectiveRange: nil) as? NSFont)?.pointSize
                ?? self.baseFont.pointSize
            guard let font = EditorFonts.cjk(family: self.cjkFamily, size: size) else { return }
            storage.addAttribute(.font, value: font, range: match.range)
        }
    }

    private static let wordRE = try! NSRegularExpression(pattern: #"\p{L}+"#)

    /// Bolds the leading ~40% of each word (whole word for ≤3 letters).
    private func applyBionic(_ storage: NSTextStorage, text: String, range: NSRange) {
        Self.wordRE.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match else { return }
            let len = match.range.length
            let boldLen = len <= 3 ? len : Int((Double(len) * 0.4).rounded(.up))
            let r = NSRange(location: match.range.location, length: max(1, min(boldLen, len)))
            let current = (storage.attribute(.font, at: r.location, effectiveRange: nil) as? NSFont) ?? self.baseFont
            storage.addAttribute(.font, value: NSFontManager.shared.convert(current, toHaveTrait: .boldFontMask), range: r)
        }
    }

    // MARK: - Per-syntax styling

    private func style(_ syntax: MarkdownSyntax, _ m: NSTextCheckingResult, _ s: NSTextStorage) {
        switch syntax {
        case .header:
            let level = max(1, group(m, "level").length)
            addFont(headingFont(level: level), m.range, s)
            addColor(theme.heading, m.range, s)
            dim(group(m, "level"), s)

        case .headerUnder:
            addFont(headingFont(level: 1), m.range, s)
            addColor(theme.heading, m.range, s)

        case .bold:
            emphasize(m, s, font: traitFont(bold: true), contentColor: nil)
        case .italicAsterisk, .italicUnderscore:
            emphasize(m, s, font: traitFont(italic: true), contentColor: nil)
        case .boldItalic:
            emphasize(m, s, font: traitFont(bold: true, italic: true), contentColor: nil)

        case .strikethrough:
            addAttr(.strikethroughStyle, NSUnderlineStyle.single.rawValue, m.range, s)
            emphasize(m, s, font: nil, contentColor: nil)

        case .code, .math:
            emphasize(m, s, font: monoFont, contentColor: theme.code)

        case .codeBlock:
            addFont(monoFont, m.range, s)
            addColor(theme.code, m.range, s)
            addAttr(.backgroundColor, theme.codeBackground, m.range, s)

        case .link, .image:
            addColor(theme.markup, m.range, s)
            addColor(theme.link, group(m, "text"), s)
        case .linkAlt, .url:
            addColor(theme.link, m.range, s)

        case .blockQuote:
            addColor(theme.blockquote, m.range, s)
            addFont(traitFont(italic: true), m.range, s)

        case .list, .checklist:
            addColor(theme.accent, group(m, "symbol"), s)
        case .orderedList:
            addColor(theme.accent, group(m, "prefix"), s)

        case .footnote, .footnoteID:
            addColor(theme.accent, m.range, s)

        case .horizontalRule, .frontmatter:
            addColor(theme.markup, m.range, s)

        case .table:
            addFont(monoFont, m.range, s)
        }
    }

    /// Applies `font` to the whole match, dims the delimiters (everything outside
    /// the "text" capture), and optionally recolors the content.
    private func emphasize(_ m: NSTextCheckingResult, _ s: NSTextStorage,
                          font: NSFont?, contentColor: NSColor?) {
        if let font { addFont(font, m.range, s) }
        let content = group(m, "text")
        guard content.location != NSNotFound else {
            if let contentColor { addColor(contentColor, m.range, s) }
            return
        }
        let whole = m.range
        let before = NSRange(location: whole.location, length: content.location - whole.location)
        addColor(theme.markup, before, s)
        let afterStart = content.location + content.length
        let after = NSRange(location: afterStart, length: whole.location + whole.length - afterStart)
        addColor(theme.markup, after, s)
        if let contentColor { addColor(contentColor, content, s) }
    }

    // MARK: - Attribute helpers (all no-op on empty / not-found ranges)

    private func group(_ m: NSTextCheckingResult, _ name: String) -> NSRange {
        m.range(withName: name)
    }
    private func dim(_ r: NSRange, _ s: NSTextStorage) { addColor(theme.markup, r, s) }
    private func addColor(_ c: NSColor, _ r: NSRange, _ s: NSTextStorage) {
        guard r.location != NSNotFound, r.length > 0 else { return }
        s.addAttribute(.foregroundColor, value: c, range: r)
    }
    private func addFont(_ f: NSFont, _ r: NSRange, _ s: NSTextStorage) {
        guard r.location != NSNotFound, r.length > 0 else { return }
        s.addAttribute(.font, value: f, range: r)
    }
    private func addAttr(_ k: NSAttributedString.Key, _ v: Any, _ r: NSRange, _ s: NSTextStorage) {
        guard r.location != NSNotFound, r.length > 0 else { return }
        s.addAttribute(k, value: v, range: r)
    }

    // MARK: - Fonts

    private var monoFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular)
    }
    private func traitFont(bold: Bool = false, italic: Bool = false) -> NSFont {
        var f = baseFont
        let fm = NSFontManager.shared
        if bold { f = fm.convert(f, toHaveTrait: .boldFontMask) }
        if italic { f = fm.convert(f, toHaveTrait: .italicFontMask) }
        return f
    }
    private func headingFont(level: Int) -> NSFont {
        let scales: [CGFloat] = [1.5, 1.3, 1.18, 1.1, 1.05, 1.0]
        let scale = scales[min(max(level, 1), 6) - 1]
        let sized = NSFont(descriptor: baseFont.fontDescriptor, size: baseFont.pointSize * scale) ?? baseFont
        return NSFontManager.shared.convert(sized, toHaveTrait: .boldFontMask)
    }
}
