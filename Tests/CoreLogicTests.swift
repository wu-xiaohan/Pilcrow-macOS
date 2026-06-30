// SPDX-License-Identifier: GPL-3.0-only
//  CoreLogicTests.swift
//  Pilcrow for macOS — unit tests for the ported core logic.

import XCTest
import AppKit
@testable import Pilcrow

final class CoreLogicTests: XCTestCase {

    private func text(of match: NSTextCheckingResult?, named name: String,
                      in s: String) -> String? {
        guard let match else { return nil }
        let r = match.range(withName: name)
        guard r.location != NSNotFound else { return nil }
        return (s as NSString).substring(with: r)
    }

    private func firstMatch(_ re: NSRegularExpression, _ s: String) -> NSTextCheckingResult? {
        re.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length))
    }

    // MARK: - Patterns

    func testBoldCapturesInnerText() {
        let s = "this is **bold** here"
        XCTAssertEqual(text(of: firstMatch(MarkdownPatterns.bold, s), named: "text", in: s), "bold")
    }

    func testItalicAsterisk() {
        let s = "an *emphasised* word"
        XCTAssertEqual(text(of: firstMatch(MarkdownPatterns.italicAsterisk, s), named: "text", in: s), "emphasised")
    }

    func testHeaderLevelAndText() {
        let s = "### Heading three\n"
        let m = firstMatch(MarkdownPatterns.header, s)
        XCTAssertEqual(text(of: m, named: "level", in: s), "###")
        XCTAssertEqual(text(of: m, named: "text", in: s), "Heading three")
    }

    func testInlineCodeBacktickBalancing() {
        let s = "use `code` now"
        XCTAssertEqual(text(of: firstMatch(MarkdownPatterns.code, s), named: "text", in: s), "code")
    }

    func testLinkCapturesTextAndURL() {
        let s = "[label](https://example.com)"
        let m = firstMatch(MarkdownPatterns.link, s)
        XCTAssertEqual(text(of: m, named: "text", in: s), "label")
        XCTAssertEqual(text(of: m, named: "url", in: s), "https://example.com")
    }

    func testAllPatternsCompiled() {
        XCTAssertEqual(MarkdownPatterns.all.count, 23)
    }

    // MARK: - Stats

    func testWordCountStripsMarkup() {
        // Bold delimiters must not inflate the word count.
        let stats = StatsEngine.compute("Hello world, this is **Apostrophe**.")
        XCTAssertEqual(stats.words, 5)
    }

    func testReadingTimeAt200wpm() {
        let oneMinute = Array(repeating: "word", count: 200).joined(separator: " ")
        let stats = StatsEngine.compute(oneMinute)
        XCTAssertEqual(stats.words, 200)
        XCTAssertEqual(stats.readingTime.minutes, 1)
        XCTAssertEqual(stats.readingTime.hours, 0)
    }

    func testParagraphCount() {
        let stats = StatsEngine.compute("First para.\n\nSecond para.\n\nThird para.")
        XCTAssertEqual(stats.paragraphs, 3)
    }

    // MARK: - Settings

    func testCharactersPerLineDefaultsAndRange() {
        XCTAssertEqual(AppDefaults.charactersPerLineDefault, 66)
        XCTAssertTrue(AppDefaults.charactersPerLineRange.contains(40))
        XCTAssertTrue(AppDefaults.charactersPerLineRange.contains(160))
        XCTAssertFalse(AppDefaults.charactersPerLineRange.contains(161))
    }

    // MARK: - Highlighter (headless attribute checks)

    private func highlighted(_ s: String) -> NSTextStorage {
        let storage = NSTextStorage(string: s)
        SyntaxHighlighter(theme: .light, baseFont: .systemFont(ofSize: 16)).highlight(storage)
        return storage
    }

    private func attr<T>(_ key: NSAttributedString.Key, _ storage: NSTextStorage,
                         at substring: String) -> T? {
        let r = (storage.string as NSString).range(of: substring)
        guard r.location != NSNotFound else { return nil }
        return storage.attribute(key, at: r.location, effectiveRange: nil) as? T
    }

    func testHighlighterMakesBoldFontBold() {
        let font: NSFont? = attr(.font, highlighted("a **bold** b"), at: "bold")
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.bold) ?? false)
    }

    func testHighlighterMakesItalicFontItalic() {
        let font: NSFont? = attr(.font, highlighted("an *em* word"), at: "em")
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.italic) ?? false)
    }

    func testHighlighterCodeIsMonospaced() {
        let font: NSFont? = attr(.font, highlighted("use `code` now"), at: "code")
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.monoSpace) ?? false)
    }

    func testHighlighterColorsHeading() {
        let color: NSColor? = attr(.foregroundColor, highlighted("# Title\n"), at: "Title")
        XCTAssertEqual(color, EditorTheme.light.heading)
        XCTAssertNotEqual(color, EditorTheme.light.foreground)
    }

    func testHighlighterDimsBoldDelimiters() {
        let color: NSColor? = attr(.foregroundColor, highlighted("a **bold** b"), at: "**")
        XCTAssertEqual(color, EditorTheme.light.markup)
    }

    // MARK: - Column metrics

    func testColumnFontShrinksAsWidthNarrows() {
        let m = ColumnMetrics(lineChars: 66, biggerText: false)
        XCTAssertEqual(m.fontSize(forWidth: 5000), m.fontSizes.first)   // widest → largest
        XCTAssertEqual(m.fontSize(forWidth: 150), m.smallestFontSize)   // narrow → 14
        XCTAssertGreaterThanOrEqual(m.fontSize(forWidth: 1200), m.fontSize(forWidth: 600))
    }

    func testColumnInsetCentersColumn() {
        let m = ColumnMetrics(lineChars: 66, biggerText: false)
        let width: CGFloat = 1400
        let size = m.fontSize(forWidth: width)
        let inset = m.horizontalInset(forWidth: width, size: size)
        XCTAssertEqual(inset, max(8, (width - m.columnWidth(size)) / 2), accuracy: 0.6)
        XCTAssertGreaterThan(m.columnWidth(size), 0)
    }

    func testBiggerTextPrependsLargerSizes() {
        XCTAssertEqual(ColumnMetrics(lineChars: 66, biggerText: true).fontSizes.first, 24)
        XCTAssertEqual(ColumnMetrics(lineChars: 66, biggerText: false).fontSizes.first, 20)
    }

    func testWiderColumnNeedsMoreWidth() {
        let narrow = ColumnMetrics(lineChars: 40, biggerText: false)
        let wide = ColumnMetrics(lineChars: 160, biggerText: false)
        XCTAssertGreaterThan(wide.columnWidth(16), narrow.columnWidth(16))
    }

    // MARK: - Pandoc preview/export

    func testPandocConvertsMarkdownToHTML() throws {
        try XCTSkipUnless(PandocRunner.isAvailable, "pandoc not installed")
        let html = try PandocRunner.markdownToHTML("# Hello\n\nA **bold** word.")
        XCTAssertTrue(html.contains("<h1"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
    }

    // MARK: - Focus mode

    func testFocusSentenceRangeContainsCaretSentence() {
        let text = "First sentence. Second sentence here. Third one."
        let r = FocusEngine.sentenceRange(in: text, at: 20)   // inside "Second sentence here."
        let s = (text as NSString).substring(with: r)
        XCTAssertTrue(s.contains("Second sentence here"))
        XCTAssertFalse(s.contains("First"))
        XCTAssertFalse(s.contains("Third"))
    }

    func testFocusSentenceRangeEmptyText() {
        XCTAssertEqual(FocusEngine.sentenceRange(in: "", at: 0), NSRange(location: 0, length: 0))
    }

    // MARK: - Export

    func testExportFormatMatrixCount() {
        XCTAssertEqual(ExportFormat.all.count, 19)
    }

    func testExportTypstPDFArgs() {
        let pdf = ExportFormat.all.first { $0.to == "pdf" && $0.engine == "typst" }!
        let args = Exporter.arguments(for: pdf, options: ExportOptions())
        XCTAssertTrue(args.contains { $0.hasPrefix("--pdf-engine=") && $0.contains("typst") })
        XCTAssertTrue(args.contains("--variable=papersize:a4"))
        XCTAssertFalse(pdf.requiresTeXLive)   // typst doesn't need TeX
    }

    func testExportLaTeXPDFRequiresTeX() {
        let pdf = ExportFormat.all.first { $0.to == "pdf" && $0.engine == "xelatex" }!
        XCTAssertTrue(pdf.requiresTeXLive)
    }

    func testExportHTMLArgsHaveMathjax() {
        let html = ExportFormat.all.first { $0.to == "html5" }!
        let args = Exporter.arguments(for: html, options: ExportOptions())
        XCTAssertTrue(args.contains("--mathjax"))
        XCTAssertTrue(args.contains("--embed-resources"))
    }

    func testExportProducesHTMLFile() throws {
        try XCTSkipUnless(PandocRunner.isAvailable, "pandoc not installed")
        let html = ExportFormat.all.first { $0.to == "html5" }!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("apostrophe_export_test.html")
        try? FileManager.default.removeItem(at: url)
        try Exporter.export(text: "# Title\n\n**Bold** and a [link](https://x.com).",
                            format: html, options: ExportOptions(), to: url)
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
        XCTAssertTrue(String(data: data, encoding: .utf8)?.contains("<h1") ?? false)
        try? FileManager.default.removeItem(at: url)
    }

    func testExportProducesTypstPDF() throws {
        try XCTSkipUnless(PandocRunner.tool("typst") != nil, "typst not installed")
        let pdf = ExportFormat.all.first { $0.to == "pdf" && $0.engine == "typst" }!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("apostrophe_export_test.pdf")
        try? FileManager.default.removeItem(at: url)
        try Exporter.export(text: "# Title\n\nBody paragraph.", format: pdf, options: ExportOptions(), to: url)
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 100)
        XCTAssertTrue(data.prefix(5).elementsEqual("%PDF-".utf8))   // PDF magic
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Smart editing

    func testWrapInsertsPlaceholderWhenNoSelection() {
        let edit = MarkdownFormatter.wrap("abc", range: NSRange(location: 3, length: 0),
                                          marker: "**", placeholder: "bold text")
        XCTAssertEqual(edit.replacement, "**bold text**")
        XCTAssertEqual(edit.selection, NSRange(location: 5, length: 9))
    }

    func testWrapWrapsTrimmedSelection() {
        let edit = MarkdownFormatter.wrap("say hello world", range: NSRange(location: 4, length: 5),
                                          marker: "**", placeholder: "x")
        XCTAssertEqual(edit.replacement, "**hello**")
    }

    func testWrapTogglesOffWhenAlreadyWrapped() {
        // "a **bold** b", select the inner "bold"
        let edit = MarkdownFormatter.wrap("a **bold** b", range: NSRange(location: 4, length: 4),
                                          marker: "**", placeholder: "x")
        XCTAssertEqual(edit.replacement, "bold")
        XCTAssertEqual(edit.range, NSRange(location: 2, length: 8))
    }

    func testWrapPreservesOuterWhitespace() {
        // Select "word " (trailing space) → markers hug the word, space stays outside.
        let edit = MarkdownFormatter.wrap("word next", range: NSRange(location: 0, length: 5),
                                          marker: "**", placeholder: "x")
        XCTAssertEqual(edit.replacement, "**word** ")
    }

    func testListContinuationOrderedIncrements() {
        let r = ListContinuation.next(for: "1. first")
        XCTAssertEqual(r?.marker, "2. ")
        XCTAssertEqual(r?.isEmptyItem, false)
    }

    func testListContinuationBulletEmptyTerminates() {
        let r = ListContinuation.next(for: "- ")
        XCTAssertEqual(r?.marker, "- ")
        XCTAssertEqual(r?.isEmptyItem, true)
    }

    func testListContinuationChecklist() {
        let r = ListContinuation.next(for: "- [x] done")
        XCTAssertEqual(r?.marker, "- [ ] ")
        XCTAssertEqual(r?.isEmptyItem, false)
    }

    func testListContinuationNonListReturnsNil() {
        XCTAssertNil(ListContinuation.next(for: "just a paragraph"))
    }

    // MARK: - Block formatting

    func testToggleBulletAddsAndRemoves() {
        XCTAssertEqual(BlockFormatter.toggleBullet("hello"), "- hello")
        XCTAssertEqual(BlockFormatter.toggleBullet("- hello"), "hello")
    }

    func testToggleBulletMultiline() {
        XCTAssertEqual(BlockFormatter.toggleBullet("a\nb"), "- a\n- b")
        XCTAssertEqual(BlockFormatter.toggleBullet("- a\n- b"), "a\nb")
    }

    func testToggleBulletOnEmptyInsertsMarker() {
        XCTAssertEqual(BlockFormatter.toggleBullet(""), "- ")
    }

    func testToggleOrderedNumbersLines() {
        XCTAssertEqual(BlockFormatter.toggleOrdered("a\nb\nc"), "1. a\n2. b\n3. c")
        XCTAssertEqual(BlockFormatter.toggleOrdered("1. a\n2. b"), "a\nb")
    }

    func testToggleChecklist() {
        XCTAssertEqual(BlockFormatter.toggleChecklist("task"), "- [ ] task")
        XCTAssertEqual(BlockFormatter.toggleChecklist("- [ ] task"), "- [x] task")  // flips check state
        XCTAssertEqual(BlockFormatter.toggleChecklist("- [x] task"), "- [ ] task")
    }

    func testBlockToggleOnBlankMiddleLineDoesNotCorruptNext() {
        // The block for a caret on a blank line is just "\n".
        XCTAssertEqual(BlockFormatter.toggleBullet("\n"), "- \n")
    }

    func testToggleBulletMixedSelectionDoesNotDouble() {
        XCTAssertEqual(BlockFormatter.toggleBullet("- a\nb"), "- a\n- b")
    }

    func testToggleQuotePreservesTrailingNewline() {
        XCTAssertEqual(BlockFormatter.toggleQuote("hi\n"), "> hi\n")
    }

    func testSetHeadingAddsRemovesAndChangesLevel() {
        XCTAssertEqual(BlockFormatter.setHeading("Title", level: 1), "# Title")
        XCTAssertEqual(BlockFormatter.setHeading("# Title", level: 1), "Title")     // toggle off
        XCTAssertEqual(BlockFormatter.setHeading("## Title", level: 1), "# Title")  // change level
    }

    // MARK: - Link insertion

    func testLinkNoSelection() {
        let e = MarkdownFormatter.link("", range: NSRange(location: 0, length: 0))
        XCTAssertEqual(e.replacement, "[link text](https://www.example.com)")
    }

    func testLinkWrapsPlainSelectionAsLabel() {
        let e = MarkdownFormatter.link("Google", range: NSRange(location: 0, length: 6))
        XCTAssertEqual(e.replacement, "[Google](https://www.example.com)")
    }

    func testLinkUsesSelectedURLAsTarget() {
        let e = MarkdownFormatter.link("https://x.com", range: NSRange(location: 0, length: 13))
        XCTAssertEqual(e.replacement, "[link text](https://x.com)")
    }

    // MARK: - List indent

    func testListIndentOnlyAffectsListLines() {
        XCTAssertEqual(ListIndenter.indent("- a\nplain"), "  - a\nplain")
        XCTAssertEqual(ListIndenter.outdent("  - a\nplain"), "- a\nplain")
    }

    func testListIndentDetection() {
        XCTAssertTrue(ListIndenter.blockHasListLine("1. one"))
        XCTAssertTrue(ListIndenter.blockHasListLine("- one"))
        XCTAssertFalse(ListIndenter.blockHasListLine("paragraph"))
    }

    // MARK: - Encoding detection

    func testEncodingUTF8RoundTrip() {
        let data = "héllo wörld".data(using: .utf8)!
        XCTAssertEqual(EncodingDetector.decode(data)?.text, "héllo wörld")
    }

    func testEncodingFallsBackForLatin1Bytes() {
        let data = Data([0x68, 0xE9, 0x6C, 0x6C, 0x6F])   // "héllo" in Latin-1/CP1252, invalid UTF-8
        let decoded = EncodingDetector.decode(data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.text, "héllo")
    }

    func testEncodingEmpty() {
        XCTAssertEqual(EncodingDetector.decode(Data())?.text, "")
    }

    func testEncodingStripsUTF8BOM() {
        let data = "\u{FEFF}hello".data(using: .utf8)!
        XCTAssertEqual(EncodingDetector.decode(data)?.text, "hello")
    }

    func testEncodingRejectsBinary() {
        XCTAssertNil(EncodingDetector.decode(Data([0x00, 0x01, 0x02, 0xFF, 0x00])))
    }
}
