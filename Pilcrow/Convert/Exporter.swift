// SPDX-License-Identifier: GPL-3.0-only
//  Exporter.swift
//  Pilcrow for macOS
//
//  Builds pandoc arguments per format/options (port of export_dialog.py's
//  retrieve_args) and runs the conversion to a file.

import Foundation

struct ExportOptions {
    var standalone = true
    var tableOfContents = false
    var numberSections = false
    var pageSizeLetter = false       // false = A4
    var slideWide = true             // true = 16:9
    var htmlSelfContained = true
    var syntaxStyle: String? = nil   // nil = pandoc default
    var incrementalBullets = false
}

enum Exporter {
    static let syntaxStyles = ["pygments", "kate", "monochrome", "espresso", "zenburn", "haddock", "tango"]

    static func bundledResource(_ name: String, _ ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "pandoc")
            ?? Bundle.main.url(forResource: name, withExtension: ext)
    }

    static func teXLiveAvailable() -> Bool {
        PandocRunner.tool("xelatex") != nil || PandocRunner.tool("pdftex") != nil
    }

    static func arguments(for format: ExportFormat, options: ExportOptions) -> [String] {
        var args = ["--from", "markdown", "--to", format.to]

        // PDF engine — resolve full paths so pandoc finds them regardless of PATH.
        if format.ext == "pdf", let engine = format.engine {
            let resolved = PandocRunner.tool(engine)?.path ?? engine
            args.append("--pdf-engine=\(resolved)")
        }

        if options.standalone || format.isPresentation
            || format.to == "latex" || format.to == "context" {
            args.append("--standalone")
        }
        if options.tableOfContents { args.append("--toc") }
        if options.numberSections { args.append("--number-sections") }

        if format.hasPages {
            let paper = options.pageSizeLetter ? "letter" : "a4"
            switch format.to {
            case "pdf", "latex", "context":
                args.append("--variable=papersize:\(paper)")
            case "odt":
                if let ref = bundledResource("reference-a4", "odt") { args.append("--reference-doc=\(ref.path)") }
            case "docx":
                if let ref = bundledResource("reference-a4", "docx") { args.append("--reference-doc=\(ref.path)") }
            default: break
            }
        }

        if format.hasSlides && options.slideWide {
            args.append("--variable=classoption:aspectratio=169")
        }

        if format.isHTML {
            args.append("--mathjax")
            if options.htmlSelfContained {
                args.append(contentsOf: ["--embed-resources", "--standalone"])
            }
        }

        if format.hasSyntax, let style = options.syntaxStyle {
            args.append("--highlight-style=\(style)")
        }

        if format.isPresentation && options.incrementalBullets {
            args.append("--incremental")
        }

        return args
    }

    static func export(text: String, format: ExportFormat,
                       options: ExportOptions, to outputURL: URL) throws {
        if format.requiresTeXLive && !teXLiveAvailable() {
            throw PandocError.failed(
                "“\(format.name)” needs a TeX installation (e.g. MacTeX). Use the Typst-based PDF instead.")
        }
        var args = arguments(for: format, options: options)
        args.append(contentsOf: ["-o", outputURL.path])
        _ = try PandocRunner.run(args, input: text)
    }

    /// Markdown → standalone HTML for the pasteboard.
    static func htmlForClipboard(_ text: String) throws -> String {
        try PandocRunner.run(
            ["--from", "markdown", "--to", "html", "--standalone", "--embed-resources", "--mathjax"],
            input: text)
    }
}
