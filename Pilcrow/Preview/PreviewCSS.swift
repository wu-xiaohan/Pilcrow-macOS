// SPDX-License-Identifier: GPL-3.0-only
//  PreviewCSS.swift
//  Pilcrow for macOS
//
//  Theme-matched CSS injected into the WKWebView preview. Bundled adwaita.css
//  from upstream can replace this later; this keeps the preview readable and on
//  theme for now.

import AppKit

extension NSColor {
    /// `#RRGGBB` in sRGB.
    var cssHex: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "#%02X%02X%02X",
                      Int(round(c.redComponent * 255)),
                      Int(round(c.greenComponent * 255)),
                      Int(round(c.blueComponent * 255)))
    }
    /// `rgba(r,g,b,a)` in sRGB (preserves alpha).
    var cssRGBA: String {
        let c = usingColorSpace(.sRGB) ?? self
        return "rgba(\(Int(round(c.redComponent * 255))),\(Int(round(c.greenComponent * 255))),"
            + "\(Int(round(c.blueComponent * 255))),\(String(format: "%.3f", c.alphaComponent)))"
    }
}

enum PreviewCSS {
    static func stylesheet(for theme: EditorTheme, charactersPerLine: Int,
                           latinFont: String, cjkFont: String) -> String {
        var faces = ""
        var families: [String] = []
        for value in [latinFont, cjkFont] {
            if let info = fontInfo(value) {
                // Served by BundledFontSchemeHandler — WKWebView won't load file://
                // fonts cross-origin (CORS), so we use a custom scheme instead.
                faces += "@font-face { font-family: '\(info.css)'; "
                    + "src: url('\(BundledFontSchemeHandler.origin)/\(info.file).ttf') format('truetype'); }\n"
                families.append("'\(info.css)'")
            }
        }
        families.append(contentsOf: ["-apple-system", "system-ui", "sans-serif"])
        let fontFamily = families.joined(separator: ", ")

        return """
        \(faces):root { color-scheme: \(theme.isDark ? "dark" : "light"); }
        html, body {
            background: \(theme.background.cssHex);
            color: \(theme.foreground.cssHex);
        }
        body {
            font-family: \(fontFamily);
            font-size: 17px;
            line-height: 1.7;
            max-width: \(charactersPerLine)ch;
            margin: 0 auto;
            padding: 3rem 2rem 6rem;
            -webkit-text-size-adjust: 100%;
        }
        h1, h2, h3, h4, h5, h6 { color: \(theme.heading.cssHex); line-height: 1.25; margin: 1.6em 0 0.6em; }
        h1 { font-size: 2em; } h2 { font-size: 1.5em; } h3 { font-size: 1.25em; }
        a { color: \(theme.link.cssHex); }
        p, li { overflow-wrap: break-word; }
        code, pre {
            font-family: ui-monospace, "SF Mono", Menlo, monospace;
            font-size: 0.9em;
        }
        code { background: \(theme.codeBackground.cssRGBA); padding: 0.15em 0.35em; border-radius: 4px; }
        pre {
            background: \(theme.codeBackground.cssRGBA);
            padding: 1em; border-radius: 8px; overflow-x: auto;
        }
        pre code { background: none; padding: 0; }
        blockquote {
            margin: 1em 0; padding: 0.2em 1em;
            color: \(theme.blockquote.cssHex);
            border-left: 3px solid \(theme.accent.cssHex);
        }
        hr { border: none; border-top: 1px solid \(theme.markup.cssRGBA); margin: 2em 0; }
        table { border-collapse: collapse; }
        th, td { border: 1px solid \(theme.markup.cssRGBA); padding: 0.4em 0.7em; }
        img { max-width: 100%; }
        """
    }

    /// Maps a font setting value to its CSS family + bundled file base name (nil
    /// for Default/System, which use the platform stack). The `.ttf` is served by
    /// `BundledFontSchemeHandler`.
    private static func fontInfo(_ value: String) -> (css: String, file: String)? {
        let map: [String: (css: String, file: String)] = [
            "Lora": ("Lora", "Lora"),
            "Shantell Sans": ("Shantell Sans", "ShantellSans"),
            "Noto Sans SC": ("Noto Sans SC", "NotoSansSC"),
            "Ma Shan Zheng": ("Ma Shan Zheng", "MaShanZheng-Regular"),
        ]
        guard let entry = map[value],
              Bundle.main.url(forResource: entry.file, withExtension: "ttf") != nil else { return nil }
        return entry
    }
}
