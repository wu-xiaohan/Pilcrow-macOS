// SPDX-License-Identifier: GPL-3.0-only
//  FocusEngine.swift
//  Pilcrow for macOS
//
//  Sentence detection for Focus Mode (dim everything but the current sentence).
//  Upstream highlights the current sentence; we use NLTokenizer for natural,
//  multilingual sentence boundaries.

import Foundation
import NaturalLanguage

enum FocusEngine {
    /// Range (NSString/UTF-16 indices) of the sentence containing `utf16Location`.
    static func sentenceRange(in text: String, at utf16Location: Int) -> NSRange {
        let ns = text as NSString
        guard ns.length > 0 else { return NSRange(location: 0, length: 0) }

        let loc = min(max(0, utf16Location), ns.length - 1)
        guard let swiftRange = Range(NSRange(location: loc, length: 0), in: text) else {
            return NSRange(location: loc, length: 0)
        }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        let tokenRange = tokenizer.tokenRange(at: swiftRange.lowerBound)
        guard !tokenRange.isEmpty else { return NSRange(location: loc, length: 0) }
        return NSRange(tokenRange, in: text)
    }
}
