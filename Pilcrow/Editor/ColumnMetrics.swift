// SPDX-License-Identifier: GPL-3.0-only
//  ColumnMetrics.swift
//  Pilcrow for macOS
//
//  Pure (testable) column sizing ported from upstream text_view.py. The body
//  font is the user's Latin font choice (default: a monospace face), and the
//  column is `lineChars` glyphs wide, centered, shrinking through a fixed ramp.

import AppKit

struct ColumnMetrics {
    var lineChars: Int
    var biggerText: Bool
    var latinFamily: String? = nil

    func bodyFont(_ size: CGFloat) -> NSFont {
        EditorFonts.body(family: latinFamily, size: size)
    }

    /// Largest → smallest, mirroring `_get_font_sizes()`.
    var fontSizes: [CGFloat] {
        biggerText ? [24, 22, 20, 18, 17, 16, 15, 14] : [20, 18, 17, 16, 15, 14]
    }
    var smallestFontSize: CGFloat { fontSizes.last ?? 14 }

    func charWidth(_ size: CGFloat) -> CGFloat {
        ("0" as NSString).size(withAttributes: [.font: bodyFont(size)]).width
    }

    func padChars(_ size: CGFloat) -> CGFloat {
        let smallest = smallestFontSize
        if biggerText {
            return max(14, 8 * CGFloat(Int(1 + (size - smallest) / 3)))
        } else {
            return max(14, 8 * (1 + size - smallest))
        }
    }

    func minWidth(_ size: CGFloat) -> CGFloat {
        (CGFloat(lineChars) + padChars(size)) * charWidth(size)
    }

    func fontSize(forWidth width: CGFloat) -> CGFloat {
        for size in fontSizes where width >= minWidth(size) { return size }
        return smallestFontSize
    }

    func columnWidth(_ size: CGFloat) -> CGFloat {
        CGFloat(lineChars) * charWidth(size)
    }

    func horizontalInset(forWidth width: CGFloat, size: CGFloat, minimum: CGFloat = 8) -> CGFloat {
        max(minimum, (width - columnWidth(size)) / 2)
    }
}
