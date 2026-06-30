// SPDX-License-Identifier: GPL-3.0-only
//  ThemePalette.swift
//  Pilcrow for macOS
//
//  Editor color palettes per theme. Mirrors upstream's light / dark / sepia
//  GtkSourceView style schemes. Sepia values match upstream (bg #F9F3E9,
//  fg #4F3915).

import AppKit

struct EditorTheme {
    let isDark: Bool
    let background: NSColor
    let foreground: NSColor
    /// Dimmed delimiters / metadata (e.g. the `**` around bold, link URLs).
    let markup: NSColor
    let heading: NSColor
    let link: NSColor
    let code: NSColor
    let codeBackground: NSColor
    let blockquote: NSColor
    let accent: NSColor

    private static func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: Double = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255,
                blue: CGFloat(b) / 255, alpha: CGFloat(a))
    }

    static let light = EditorTheme(
        isDark: false,
        background: rgb(0xFA, 0xFA, 0xFA),
        foreground: rgb(0x24, 0x24, 0x24),
        markup: NSColor(white: 0, alpha: 0.32),
        heading: rgb(0x1A, 0x1A, 0x1A),
        link: rgb(0x1C, 0x71, 0xD8),
        code: rgb(0xA1, 0x1A, 0x66),
        codeBackground: NSColor(white: 0, alpha: 0.05),
        blockquote: NSColor(white: 0, alpha: 0.55),
        accent: rgb(0x8A, 0x5A, 0x12))

    static let dark = EditorTheme(
        isDark: true,
        background: rgb(0x1E, 0x1E, 0x1E),
        foreground: rgb(0xD4, 0xD4, 0xD4),
        markup: NSColor(white: 1, alpha: 0.32),
        heading: rgb(0xF0, 0xF0, 0xF0),
        link: rgb(0x78, 0xAE, 0xED),
        code: rgb(0xE0, 0x8B, 0xC4),
        codeBackground: NSColor(white: 1, alpha: 0.06),
        blockquote: NSColor(white: 1, alpha: 0.55),
        accent: rgb(0xE6, 0xB4, 0x50))

    static let sepia = EditorTheme(
        isDark: false,
        background: rgb(0xF9, 0xF3, 0xE9),
        foreground: rgb(0x4F, 0x39, 0x15),
        markup: rgb(0x4F, 0x39, 0x15, 0.40),
        heading: rgb(0x3A, 0x2A, 0x0F),
        link: rgb(0x8A, 0x5A, 0x12),
        code: rgb(0x7A, 0x3B, 0x2E),
        codeBackground: rgb(0x4F, 0x39, 0x15, 0.06),
        blockquote: rgb(0x4F, 0x39, 0x15, 0.65),
        accent: rgb(0x8A, 0x5A, 0x12))

    static func resolve(_ scheme: AppColorScheme, systemIsDark: Bool, customHex: String? = nil) -> EditorTheme {
        switch scheme {
        case .system: return systemIsDark ? .dark : .light
        case .light:  return .light
        case .dark:   return .dark
        case .sepia:  return .sepia
        case .lavenderMist: return soft(bg: rgb(0xED, 0xE9, 0xF5), fg: rgb(0x3A, 0x34, 0x50), accent: rgb(0x7A, 0x6F, 0xB0))
        case .periwinkle:   return soft(bg: rgb(0xE6, 0xE9, 0xF7), fg: rgb(0x33, 0x38, 0x4F), accent: rgb(0x6B, 0x78, 0xC9))
        case .softSky:      return soft(bg: rgb(0xE6, 0xF0, 0xF7), fg: rgb(0x2E, 0x3C, 0x46), accent: rgb(0x4F, 0x90, 0xB5))
        case .softApricot:  return soft(bg: rgb(0xFB, 0xED, 0xE0), fg: rgb(0x4A, 0x3A, 0x2C), accent: rgb(0xC8, 0x89, 0x5A))
        case .warmSand:     return soft(bg: rgb(0xF3, 0xEA, 0xDB), fg: rgb(0x46, 0x3E, 0x2E), accent: rgb(0xB7, 0x9A, 0x6A))
        case .sage:         return soft(bg: rgb(0xE8, 0xEF, 0xE6), fg: rgb(0x2F, 0x3A, 0x2E), accent: rgb(0x6E, 0x94, 0x66))
        case .custom:       return custom(hex: customHex)
        }
    }

    /// Builds a light theme from a background/foreground/accent triple.
    private static func soft(bg: NSColor, fg: NSColor, accent: NSColor) -> EditorTheme {
        EditorTheme(isDark: false, background: bg, foreground: fg,
                    markup: fg.withAlphaComponent(0.40), heading: fg,
                    link: accent, code: accent,
                    codeBackground: fg.withAlphaComponent(0.06),
                    blockquote: fg.withAlphaComponent(0.60), accent: accent)
    }

    private static func custom(hex: String?) -> EditorTheme {
        let bg = NSColor(hex: hex ?? "#FBF1E6") ?? .white
        let dark = bg.luminance < 0.5
        let fg = dark ? rgb(0xE6, 0xE6, 0xE6) : rgb(0x2A, 0x2A, 0x2A)
        return EditorTheme(isDark: dark, background: bg, foreground: fg,
                           markup: fg.withAlphaComponent(0.40), heading: fg,
                           link: dark ? rgb(0x78, 0xAE, 0xED) : rgb(0x1C, 0x71, 0xD8),
                           code: dark ? rgb(0xE0, 0x8B, 0xC4) : rgb(0xA1, 0x1A, 0x66),
                           codeBackground: fg.withAlphaComponent(0.06),
                           blockquote: fg.withAlphaComponent(0.60),
                           accent: .controlAccentColor)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    /// Relative luminance in sRGB (0…1).
    var luminance: CGFloat {
        guard let c = usingColorSpace(.sRGB) else { return 0.5 }
        return 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
    }
}
