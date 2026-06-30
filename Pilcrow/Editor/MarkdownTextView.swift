// SPDX-License-Identifier: GPL-3.0-only
//  MarkdownTextView.swift
//  Pilcrow for macOS
//
//  NSViewRepresentable hosting an PilcrowTextView (centered column + dynamic
//  font) with live Markdown highlighting. Markdown is kept literal (no smart
//  substitutions). Focus mode and typewriter scrolling are layered on next.

import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var theme: EditorTheme
    var charactersPerLine: Int
    var biggerText: Bool
    var spellcheck: Bool
    var focusMode: Bool
    var hemingwayMode: Bool
    var bionicReading: Bool
    var latinFamily: String
    var cjkFamily: String
    var fileURL: URL?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true

        let textView = PilcrowTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        // Keep Markdown literal.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false

        textView.string = text
        textView.lineChars = charactersPerLine
        textView.biggerText = biggerText
        textView.onFontChange = { [weak coord = context.coordinator] font in
            coord?.baseFontChanged(font)
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.configure(textView)
        context.coordinator.highlightNow()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? PilcrowTextView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.configure(textView)
            context.coordinator.highlightNow()
        } else {
            context.coordinator.configure(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: PilcrowTextView?
        private var highlighter: SyntaxHighlighter?
        private var pending: DispatchWorkItem?

        init(_ parent: MarkdownTextView) { self.parent = parent }

        func configure(_ tv: PilcrowTextView) {
            tv.backgroundColor = parent.theme.background
            tv.enclosingScrollView?.backgroundColor = parent.theme.background
            tv.insertionPointColor = parent.theme.accent
            tv.isContinuousSpellCheckingEnabled = parent.spellcheck
            tv.focusDimColor = parent.theme.markup
            tv.lineChars = parent.charactersPerLine
            tv.biggerText = parent.biggerText
            tv.focusMode = parent.focusMode
            tv.hemingwayMode = parent.hemingwayMode
            tv.documentDirectory = parent.fileURL?.deletingLastPathComponent()
            tv.latinFamily = parent.latinFamily

            let base = tv.currentBodyFont
            tv.typingAttributes = [.font: base, .foregroundColor: parent.theme.foreground]
            if let h = highlighter {
                h.theme = parent.theme
                h.baseFont = base
            } else {
                highlighter = SyntaxHighlighter(theme: parent.theme, baseFont: base)
            }
            highlighter?.bionic = parent.bionicReading
            highlighter?.cjkFamily = parent.cjkFamily
            scheduleHighlight()
        }

        func baseFontChanged(_ font: NSFont) {
            highlighter?.baseFont = font
            scheduleHighlight()
        }

        func highlightNow() {
            guard let tv = textView, let ts = tv.textStorage, let h = highlighter else { return }
            h.highlight(ts)
            if tv.focusMode { tv.applyFocusDimming() }
        }

        private func scheduleHighlight() {
            pending?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.highlightNow() }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: work)
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            scheduleHighlight()
        }
    }
}
