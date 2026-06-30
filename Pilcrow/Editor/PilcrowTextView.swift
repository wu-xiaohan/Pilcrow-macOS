// SPDX-License-Identifier: GPL-3.0-only
//  PilcrowTextView.swift
//  Pilcrow for macOS
//
//  NSTextView subclass providing the signature Apostrophe editor behaviors:
//  a centered, width-constrained column with a dynamic font ramp, plus Focus
//  Mode (dim all but the current sentence + typewriter vertical centering).

import AppKit
import UniformTypeIdentifiers

final class PilcrowTextView: NSTextView {

    /// Folder of the current document, used to make inserted image paths relative.
    var documentDirectory: URL?

    var lineChars: Int = 66 {
        didSet { if lineChars != oldValue { recomputeColumn() } }
    }
    var biggerText: Bool = false {
        didSet { if biggerText != oldValue { recomputeColumn() } }
    }
    var latinFamily: String? {
        didSet { if latinFamily != oldValue { recomputeColumn() } }
    }
    var focusMode: Bool = false {
        didSet { if focusMode != oldValue { focusModeChanged() } }
    }
    var focusDimColor: NSColor = .disabledControlTextColor
    /// Called when the chosen body font size changes (so the highlighter reruns).
    var onFontChange: ((NSFont) -> Void)?

    private(set) var bodyFontSize: CGFloat = 16
    var currentBodyFont: NSFont {
        ColumnMetrics(lineChars: lineChars, biggerText: biggerText, latinFamily: latinFamily).bodyFont(bodyFontSize)
    }
    private let baseVerticalInset: CGFloat = 28

    // MARK: - Layout

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        recomputeColumn(availableWidth: newSize.width)
    }

    func recomputeColumn(availableWidth: CGFloat? = nil) {
        let clip = enclosingScrollView?.contentView.bounds
        let width = availableWidth ?? clip?.width ?? bounds.width
        guard width > 1 else { return }

        let metrics = ColumnMetrics(lineChars: lineChars, biggerText: biggerText, latinFamily: latinFamily)

        let newSize = metrics.fontSize(forWidth: width)
        if newSize != bodyFontSize {
            bodyFontSize = newSize
        }
        let font = metrics.bodyFont(bodyFontSize)
        typingAttributes[.font] = font
        onFontChange?(font)

        let hInset = metrics.horizontalInset(forWidth: width, size: bodyFontSize)
        let height = clip?.height ?? bounds.height
        let vInset = focusMode ? max(baseVerticalInset, height / 2) : baseVerticalInset
        let target = NSSize(width: hInset, height: vInset)
        if abs(textContainerInset.width - target.width) > 0.5
            || abs(textContainerInset.height - target.height) > 0.5 {
            textContainerInset = target
        }
        if focusMode { scheduleCenterCaret() }
    }

    // MARK: - Focus mode

    private func focusModeChanged() {
        recomputeColumn()
        applyFocusDimming()
        if focusMode { scheduleCenterCaret() }
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity,
                                    stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        if focusMode && !stillSelecting {
            applyFocusDimming()
            scheduleCenterCaret()
        }
    }

    override func didChangeText() {
        super.didChangeText()
        if focusMode { applyFocusDimming() }
    }

    /// Dims everything but the current sentence using temporary (render-only)
    /// attributes, so the highlighter's text-storage attributes stay intact.
    func applyFocusDimming() {
        guard let lm = layoutManager else { return }
        let full = NSRange(location: 0, length: (string as NSString).length)
        lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
        guard focusMode, full.length > 0 else { return }

        lm.addTemporaryAttribute(.foregroundColor, value: focusDimColor, forCharacterRange: full)
        let sentence = FocusEngine.sentenceRange(in: string, at: selectedRange().location)
        if sentence.length > 0 {
            lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: sentence)
        }
    }

    private func scheduleCenterCaret() {
        DispatchQueue.main.async { [weak self] in self?.centerCaret() }
    }

    /// Scrolls so the caret line sits at the vertical center (typewriter scroll).
    private func centerCaret() {
        guard focusMode, let lm = layoutManager, let tc = textContainer,
              let scroll = enclosingScrollView else { return }
        let glyphRange = lm.glyphRange(forCharacterRange: selectedRange(), actualCharacterRange: nil)
        var rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        rect.origin.y += textContainerInset.height
        let clipHeight = scroll.contentView.bounds.height
        let maxY = max(0, frame.height - clipHeight)
        let targetY = min(max(0, rect.midY - clipHeight / 2), maxY)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    // MARK: - Smart editing

    var hemingwayMode = false

    private static let autoPairs: [String: String] = ["(": ")", "[": "]", "{": "}", "`": "`"]
    private static let closers: Set<String> = [")", "]", "}", "`"]

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        guard let s = insertString as? String, s.count == 1 else {
            super.insertText(insertString, replacementRange: replacementRange); return
        }
        let ns = string as NSString
        let sel = (replacementRange.location != NSNotFound) ? replacementRange : selectedRange()

        // Step over a matching closing character instead of inserting a new one.
        if sel.length == 0, Self.closers.contains(s), sel.location < ns.length,
           ns.substring(with: NSRange(location: sel.location, length: 1)) == s {
            setSelectedRange(NSRange(location: sel.location + 1, length: 0))
            return
        }

        // Auto-pair, or wrap the selection.
        if let close = Self.autoPairs[s] {
            let selected = sel.length > 0 ? ns.substring(with: sel) : ""
            let replacement = s + selected + close
            if shouldChangeText(in: sel, replacementString: replacement) {
                textStorage?.replaceCharacters(in: sel, with: replacement)
                didChangeText()
                setSelectedRange(NSRange(location: sel.location + 1, length: (selected as NSString).length))
            }
            return
        }

        super.insertText(insertString, replacementRange: replacementRange)
    }

    override func insertNewline(_ sender: Any?) {
        let sel = selectedRange()
        guard sel.length == 0 else { super.insertNewline(sender); return }

        let ns = string as NSString
        let lineRange = ns.lineRange(for: NSRange(location: sel.location, length: 0))
        var line = ns.substring(with: lineRange)
        if line.hasSuffix("\n") { line = String(line.dropLast()) }

        guard let cont = ListContinuation.next(for: line) else {
            super.insertNewline(sender); return
        }
        if cont.isEmptyItem {
            // Empty item → terminate the list by clearing the marker-only line.
            let clear = NSRange(location: lineRange.location, length: (line as NSString).length)
            if shouldChangeText(in: clear, replacementString: "") {
                textStorage?.replaceCharacters(in: clear, with: "")
                didChangeText()
                setSelectedRange(NSRange(location: lineRange.location, length: 0))
            }
            return
        }
        let insert = "\n" + cont.marker
        if shouldChangeText(in: sel, replacementString: insert) {
            textStorage?.replaceCharacters(in: sel, with: insert)
            didChangeText()
            setSelectedRange(NSRange(location: sel.location + (insert as NSString).length, length: 0))
        }
    }

    // MARK: - Format toggles (Format menu)

    @objc func toggleBold(_ sender: Any?) { applyWrap("**", "bold text") }
    @objc func toggleItalic(_ sender: Any?) { applyWrap("_", "italic text") }
    @objc func toggleStrikethrough(_ sender: Any?) { applyWrap("~~", "strikethrough text") }
    @objc func toggleInlineCode(_ sender: Any?) { applyWrap("`", "code") }

    private func applyWrap(_ marker: String, _ placeholder: String) {
        let edit = MarkdownFormatter.wrap(string as NSString, range: selectedRange(),
                                          marker: marker, placeholder: placeholder)
        guard shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
        textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
        didChangeText()
        setSelectedRange(edit.selection)
    }

    // MARK: - Block format actions (Format menu)

    @objc func toggleBulletList(_ sender: Any?) { applyBlock { BlockFormatter.toggleBullet($0) } }
    @objc func toggleOrderedList(_ sender: Any?) { applyBlock { BlockFormatter.toggleOrdered($0) } }
    @objc func toggleChecklist(_ sender: Any?) { applyBlock { BlockFormatter.toggleChecklist($0) } }
    @objc func toggleBlockquote(_ sender: Any?) { applyBlock { BlockFormatter.toggleQuote($0) } }
    @objc func setHeading1(_ sender: Any?) { applyBlock { BlockFormatter.setHeading($0, level: 1) } }
    @objc func setHeading2(_ sender: Any?) { applyBlock { BlockFormatter.setHeading($0, level: 2) } }
    @objc func setHeading3(_ sender: Any?) { applyBlock { BlockFormatter.setHeading($0, level: 3) } }
    @objc func setHeading4(_ sender: Any?) { applyBlock { BlockFormatter.setHeading($0, level: 4) } }
    @objc func setHeading5(_ sender: Any?) { applyBlock { BlockFormatter.setHeading($0, level: 5) } }
    @objc func setHeading6(_ sender: Any?) { applyBlock { BlockFormatter.setHeading($0, level: 6) } }

    @objc func insertHorizontalRule(_ sender: Any?) { insertAtCaret("\n\n---\n") }

    @objc func insertLink(_ sender: Any?) {
        let edit = MarkdownFormatter.link(string as NSString, range: selectedRange())
        guard shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
        textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
        didChangeText()
        setSelectedRange(edit.selection)
    }

    @objc func insertImage(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let sel = selectedRange()
        let ns = string as NSString
        let alt = sel.length > 0 ? ns.substring(with: sel) : "image caption"   // use selection as caption
        let path = relativePath(for: url)
        let replacement = "![\(alt)](\(path))"
        guard shouldChangeText(in: sel, replacementString: replacement) else { return }
        textStorage?.replaceCharacters(in: sel, with: replacement)
        didChangeText()
        setSelectedRange(NSRange(location: sel.location + 2, length: (alt as NSString).length))  // select alt text
    }

    private func relativePath(for url: URL) -> String {
        let raw: String
        if let dir = documentDirectory {
            let base = dir.standardizedFileURL.path
            let target = url.standardizedFileURL.path
            raw = target.hasPrefix(base + "/") ? String(target.dropFirst(base.count + 1)) : target
        } else {
            raw = url.path
        }
        let allowed = CharacterSet(charactersIn: "/").union(.urlPathAllowed)
        return raw.addingPercentEncoding(withAllowedCharacters: allowed) ?? raw
    }

    // MARK: - Tab / Shift-Tab list indenting

    override func insertTab(_ sender: Any?) {
        if applyListIndent(outdent: false) { return }
        super.insertTab(sender)
    }

    override func insertBacktab(_ sender: Any?) {
        if applyListIndent(outdent: true) { return }
        super.insertBacktab(sender)
    }

    /// Indents/outdents list lines covered by the selection. Returns true if it
    /// handled the key (i.e. the block contains a list line).
    private func applyListIndent(outdent: Bool) -> Bool {
        let ns = string as NSString
        let lineRange = ns.lineRange(for: selectedRange())
        let block = ns.substring(with: lineRange)
        guard ListIndenter.blockHasListLine(block) else { return false }

        let replacement = outdent ? ListIndenter.outdent(block) : ListIndenter.indent(block)
        if replacement == block { return true }  // consumed, nothing to change
        guard shouldChangeText(in: lineRange, replacementString: replacement) else { return true }

        let sel = selectedRange()
        // Map the selection onto the new text via per-line length deltas.
        let oldLines = block.components(separatedBy: "\n")
        let newLines = replacement.components(separatedBy: "\n")
        var newStart = sel.location, newEnd = sel.location + sel.length
        var offset = lineRange.location
        for i in 0..<oldLines.count {
            let nl = (i < oldLines.count - 1) ? 1 : 0
            let oldLen = (oldLines[i] as NSString).length + nl
            let newLen = (i < newLines.count ? (newLines[i] as NSString).length : 0) + nl
            let delta = newLen - oldLen
            if offset < sel.location { newStart += delta }
            if offset < sel.location + sel.length { newEnd += delta }
            offset += oldLen
        }
        textStorage?.replaceCharacters(in: lineRange, with: replacement)
        didChangeText()
        let docLen = (string as NSString).length
        newStart = max(lineRange.location, min(newStart, docLen))
        newEnd = max(newStart, min(newEnd, docLen))
        setSelectedRange(NSRange(location: newStart, length: newEnd - newStart))
        return true
    }

    @objc func insertCodeBlock(_ sender: Any?) {
        let ns = string as NSString
        let line = ns.substring(with: ns.lineRange(for: selectedRange()))
            .trimmingCharacters(in: .newlines)
        if line.isEmpty {
            insertAtCaret("```\n\n```", caretOffset: 4)   // caret on the empty fenced line
        } else {
            applyWrap("`", "code")
        }
    }

    /// Applies `transform` to the full lines covered by the selection.
    private func applyBlock(_ transform: (String) -> String) {
        let ns = string as NSString
        let lineRange = ns.lineRange(for: selectedRange())
        let replacement = transform(ns.substring(with: lineRange))
        guard shouldChangeText(in: lineRange, replacementString: replacement) else { return }
        textStorage?.replaceCharacters(in: lineRange, with: replacement)
        didChangeText()
        let nsRepl = replacement as NSString
        var caret = lineRange.location + nsRepl.length
        if nsRepl.hasSuffix("\n") { caret -= 1 }   // stay on the affected line, not the next
        setSelectedRange(NSRange(location: min(caret, (string as NSString).length), length: 0))
    }

    private func insertAtCaret(_ text: String, caretOffset: Int? = nil) {
        let sel = selectedRange()
        guard shouldChangeText(in: sel, replacementString: text) else { return }
        textStorage?.replaceCharacters(in: sel, with: text)
        didChangeText()
        setSelectedRange(NSRange(location: sel.location + (caretOffset ?? (text as NSString).length), length: 0))
    }

    // MARK: - Hemingway mode (no deletions)

    override func deleteBackward(_ sender: Any?) {
        if hemingwayMode { NSSound.beep(); return }
        super.deleteBackward(sender)
    }
    override func deleteForward(_ sender: Any?) {
        if hemingwayMode { return }
        super.deleteForward(sender)
    }
    override func deleteWordBackward(_ sender: Any?) {
        if hemingwayMode { return }
        super.deleteWordBackward(sender)
    }
}
