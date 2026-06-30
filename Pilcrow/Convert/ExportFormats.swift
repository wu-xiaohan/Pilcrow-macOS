// SPDX-License-Identifier: GPL-3.0-only
//  ExportFormats.swift
//  Pilcrow for macOS
//
//  Port of upstream data/media/formats.json + the `Format` property helpers in
//  export_dialog.py.

import Foundation

struct ExportFormat: Identifiable, Hashable {
    let name: String
    let ext: String
    let to: String
    let engine: String?

    var id: String { name }

    var hasPages: Bool { ["pdf", "odt", "docx", "latex"].contains(to) }
    var hasSlides: Bool { to == "beamer" }
    var isHTML: Bool { to == "html5" }
    var hasSyntax: Bool { ["html", "tex", "docx", "pdf"].contains(ext) && engine != "typst" }
    var isPresentation: Bool { ["beamer", "revealjs", "dzslides"].contains(to) }
    var requiresTeXLive: Bool { ["tex", "pdf"].contains(ext) && engine != "typst" }
    var exportsFolder: Bool { to == "revealjs" }

    static let all: [ExportFormat] = [
        .init(name: "PDF", ext: "pdf", to: "pdf", engine: "typst"),
        .init(name: "PDF (LaTeX)", ext: "pdf", to: "pdf", engine: "xelatex"),
        .init(name: "LibreOffice Text Document", ext: "odt", to: "odt", engine: nil),
        .init(name: "Microsoft Word (docx)", ext: "docx", to: "docx", engine: nil),
        .init(name: "EPUB v3", ext: "epub", to: "epub", engine: nil),
        .init(name: "HTML5 Slideshow (reveal.js)", ext: "html", to: "revealjs", engine: nil),
        .init(name: "LaTeX Beamer Slideshow (pdf)", ext: "pdf", to: "beamer", engine: "xelatex"),
        .init(name: "LaTeX Beamer Slideshow (tex)", ext: "tex", to: "beamer", engine: nil),
        .init(name: "HTML5 Slideshow (DZSlides)", ext: "html", to: "dzslides", engine: nil),
        .init(name: "LaTeX (tex)", ext: "tex", to: "latex", engine: nil),
        .init(name: "HTML", ext: "html", to: "html5", engine: nil),
        .init(name: "MediaWiki Markup", ext: "txt", to: "mediawiki", engine: nil),
        .init(name: "DokuWiki Markup", ext: "txt", to: "dokuwiki", engine: nil),
        .init(name: "ConTeXt", ext: "tex", to: "context", engine: nil),
        .init(name: "Textile", ext: "txt", to: "textile", engine: nil),
        .init(name: "reStructuredText", ext: "txt", to: "rst", engine: nil),
        .init(name: "Texinfo", ext: "texi", to: "texinfo", engine: nil),
        .init(name: "Rich Text Format", ext: "rtf", to: "rtf", engine: nil),
        .init(name: "Groff Man", ext: "man", to: "man", engine: nil),
    ]
}
