// SPDX-License-Identifier: GPL-3.0-only
//  PyMuPDF4LLMRunner.swift
//  Pilcrow for macOS
//
//  Rich PDF import via pymupdf4llm (https://github.com/pymupdf/RAG). Best for
//  academic papers: keeps two-column reading order, tables, and extracts figures
//  to image files (referenced relatively, so the preview renders them and the
//  editor stays fast — no giant inline base64).
//
//  After conversion, footnotes and images are moved out of the reading flow to
//  the end (footnotes, then figures). It leaves a `***` rule where a footnote was
//  lifted (marking the page boundary lost in conversion), recovers footnotes the
//  converter merged into the body by their sequential number, and stitches
//  page-straddling footnote continuations back onto the footnote they belong to.
//
//  Not bundled — a Python tool, so this is a local/personal feature. Set up once:
//      python3.10 -m venv ~/.pilcrow-pdf-venv
//      ~/.pilcrow-pdf-venv/bin/pip install pymupdf4llm

import AppKit
import Foundation
import UniformTypeIdentifiers

enum PyMuPDF4LLMRunner {
    enum ImportError: LocalizedError {
        case notInstalled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "PyMuPDF4LLM isn’t set up. Create its helper environment once:\n\n"
                    + "    python3.10 -m venv ~/.pilcrow-pdf-venv\n"
                    + "    ~/.pilcrow-pdf-venv/bin/pip install pymupdf4llm"
            case .failed(let message):
                return "PyMuPDF4LLM couldn’t convert this file.\n\n\(message)"
            }
        }
    }

    private static let script = """
    import pymupdf4llm, sys
    md = pymupdf4llm.to_markdown(sys.argv[1], write_images=True, image_path="imgs", image_format="png", dpi=120)
    open(sys.argv[2], "w", encoding="utf-8").write(md)
    """

    /// Prompt for a PDF to import.
    @MainActor
    static func pickInputFile() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Import PDF as Markdown"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Convert a PDF to Markdown with figures extracted to an `imgs/` folder next
    /// to the returned `.md`, and footnotes/images relocated to the end.
    static func convert(_ input: URL) throws -> URL {
        guard let python = pythonExecutable() else { throw ImportError.notInstalled }

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("pilcrow-pdf-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // Copy to a URL-safe name so extracted image filenames don't contain
        // characters (like "?") that break image links in the preview.
        let clean = sanitized(input.deletingPathExtension().lastPathComponent)
        let src = folder.appendingPathComponent("\(clean).pdf")
        try FileManager.default.copyItem(at: input, to: src)
        let output = folder.appendingPathComponent("\(clean).md")

        let process = Process()
        process.executableURL = python
        process.arguments = ["-c", script, src.path, output.path]
        process.currentDirectoryURL = folder            // so image_path="imgs" is relative
        process.standardOutput = FileHandle.nullDevice
        let stderr = Pipe()
        process.standardError = stderr

        do { try process.run() } catch { throw ImportError.failed(error.localizedDescription) }
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try? FileManager.default.removeItem(at: src)     // keep only the .md + imgs/

        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: output.path) else {
            let message = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if message.contains("No module named") { throw ImportError.notInstalled }
            throw ImportError.failed(message.isEmpty ? "Exited with status \(process.terminationStatus)." : message)
        }

        if let raw = try? String(contentsOf: output, encoding: .utf8) {
            try? Data(reorderingFootnotesAndImages(raw).utf8).write(to: output)
        }
        return output
    }

    // MARK: - Footnote / image relocation

    private static func reorderingFootnotesAndImages(_ text: String) -> String {
        let blocks = paragraphBlocks(text)

        // The footnote sequence is defined by numbers that appear as `> N …`.
        var found = Set<Int>()
        for block in blocks {
            let t = block.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix(">") else { continue }
            let rest = t.dropFirst().drop { $0 == " " }
            if let f = rest.first, f.isNumber, let n = leadingNumber(String(rest)) { found.insert(n) }
        }
        let missing = found.isEmpty ? Set<Int>() : Set(1...(found.max() ?? 0)).subtracting(found)

        var body: [String] = []
        var footnotes: [(number: Int?, text: String)] = []
        var images: [(number: Int, markdown: String)] = []
        var figureIndex = 0
        var bodySinceFootnote = false

        // Track the run of footnotes lifted at one spot, so we can leave a labelled
        // marker ("footnotes 3 to 5 moved to the end") instead of a bare rule.
        var clusterNumbers: [Int] = []
        var clusterCount = 0
        func flushCluster() {
            guard clusterCount > 0 else { return }
            body.append(clusterMarker(clusterNumbers))
            clusterNumbers = []; clusterCount = 0
        }

        for block in blocks {
            let t = block.trimmingCharacters(in: .whitespaces)
            let isFootnote = isBlockquoteFootnote(t)
                || (footnoteStartNumber(t).map { missing.contains($0) } ?? false)

            if t.contains("![") {
                flushCluster()
                figureIndex += 1
                images.append((figureIndex, t))
                body.append(figureMarker(figureIndex))   // linked "Figure N moved to the end"
                bodySinceFootnote = false
            } else if isFootnote {
                // Stitch a page-straddling continuation onto the previous footnote:
                // only when that footnote looks unfinished, real body appeared after
                // it, and the last body block resumes mid-sentence (lowercase / URL /
                // CJK — never a capitalised new paragraph).
                if let last = footnotes.last, isOpen(last.text), bodySinceFootnote,
                   let candidate = body.last, isContinuationStart(candidate) {
                    body.removeLast()
                    footnotes[footnotes.count - 1].text = last.text + " " + candidate.trimmingCharacters(in: .whitespaces)
                }
                let footnote = stripMarker(t)
                let number = leadingNumber(footnote)
                footnotes.append((number, footnote))
                clusterCount += 1
                if let n = number { clusterNumbers.append(n) }
                bodySinceFootnote = false
            } else if t.hasPrefix(">"), !footnotes.isEmpty {
                // Adjacent `>` continuation (no number) — merge into the footnote.
                footnotes[footnotes.count - 1].text += " " + stripMarker(t)
            } else if isBareNumber(t) {
                // page number / inline marker — drop
            } else {
                flushCluster()
                body.append(block); bodySinceFootnote = true
            }
        }
        flushCluster()

        var out = linkFootnoteMarkers(
            collapseBlankRuns(body.joined(separator: "\n\n")).trimmingCharacters(in: .whitespacesAndNewlines))
        if !footnotes.isEmpty {
            let ordered = footnotes.sorted { ($0.number ?? -1) < ($1.number ?? -1) }
            out += "\n\n---\n\n## Footnotes\n\n" + ordered.map(formatFootnote).joined(separator: "\n\n")
        }
        if !images.isEmpty {
            out += "\n\n---\n\n## Figures\n\n" + images.map(formatFigure).joined(separator: "\n\n")
        }
        return out + "\n"
    }

    /// Split text into paragraph blocks (separated by blank lines); keeps a block's
    /// internal newlines (e.g. tables).
    private static func paragraphBlocks(_ text: String) -> [String] {
        var blocks: [String] = []
        var current: [String] = []
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty { blocks.append(current.joined(separator: "\n")); current = [] }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { blocks.append(current.joined(separator: "\n")) }
        return blocks
    }

    /// A labelled divider marking where a run of footnotes was lifted from the body.
    private static func clusterMarker(_ numbers: [Int]) -> String {
        let sorted = numbers.sorted()
        let label: String
        if let lo = sorted.first, let hi = sorted.last {
            label = lo == hi ? "footnote \(lo) moved to the end"
                             : "footnotes \(lo) to \(hi) moved to the end"
        } else {
            label = "footnote moved to the end"
        }
        return "*—— \(label) ——*"
    }

    /// Turns each `<sup>N</sup>` marker in the body into a link to footnote N (and an
    /// anchor the footnote's back-link returns to), for jump-to navigation.
    private static func linkFootnoteMarkers(_ text: String) -> String {
        guard let re = try? NSRegularExpression(pattern: "<sup>(\\d+)</sup>") else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return re.stringByReplacingMatches(in: text, range: range,
            withTemplate: "<sup><a id=\"pcfnref-$1\" href=\"#pcfn-$1\">$1</a></sup>")
    }

    /// Formats a footnote with an anchor (jump target) and a back-link to the body.
    private static func formatFootnote(_ footnote: (number: Int?, text: String)) -> String {
        guard let n = footnote.number else { return footnote.text }
        return "<a id=\"pcfn-\(n)\"></a>\(footnote.text) [↩](#pcfnref-\(n))"
    }

    /// A labelled, linked marker left in the body where a figure was lifted. Starts
    /// with `*` so the continuation stitcher never mistakes it for footnote text.
    private static func figureMarker(_ n: Int) -> String {
        "*—— [Figure \(n) moved to the end](#pcfig-\(n)) ——*<a id=\"pcfigref-\(n)\"></a>"
    }

    /// Formats a figure with an anchor (jump target) and a back-link to the body.
    private static func formatFigure(_ figure: (number: Int, markdown: String)) -> String {
        "<a id=\"pcfig-\(figure.number)\"></a>**Figure \(figure.number)** [↩](#pcfigref-\(figure.number))\n\n\(figure.markdown)"
    }

    /// A blockquote footnote: `>` then a number or a footnote symbol (∗ * → _).
    private static func isBlockquoteFootnote(_ s: String) -> Bool {
        guard s.hasPrefix(">") else { return false }
        let rest = s.dropFirst().drop { $0 == " " }
        guard let first = rest.first else { return false }
        return first.isNumber || "_*∗→".contains(first)
    }

    private static func stripMarker(_ b: String) -> String {
        let t = b.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix(">") ? stripBlockquote(t) : t
    }

    private static func stripBlockquote(_ s: String) -> String {
        var r = Substring(s)
        if r.hasPrefix(">") { r = r.dropFirst() }
        if r.hasPrefix(" ") { r = r.dropFirst() }
        return String(r)
    }

    private static func isBareNumber(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy(\.isNumber)
    }

    /// Leading integer of a string (e.g. "12github…" → 12), or nil.
    private static func leadingNumber(_ s: String) -> Int? {
        let digits = s.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// If a block looks like a merged footnote — a leading number then prose (not a
    /// "6." list item, not a "10-token" value, not a bare number, not a header) —
    /// return that number.
    private static func footnoteStartNumber(_ s: String) -> Int? {
        guard !s.hasPrefix("#"), !s.hasPrefix("*") else { return nil }
        let digits = s.prefix { $0.isNumber }
        guard !digits.isEmpty, let n = Int(digits) else { return nil }
        let rest = s.dropFirst(digits.count)
        guard rest.first != "." else { return nil }
        let afterSpaces = rest.drop { $0 == " " }
        guard let c = afterSpaces.first, c.isLetter else { return nil }
        guard s.contains(".") else { return nil }
        return n
    }

    /// A footnote reads as finished (ends in sentence punctuation or a URL). If not,
    /// it may continue on the next page.
    private static func endsComplete(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard let last = t.last else { return true }
        if ".?!:;)\"”】]".contains(last) { return true }
        let tail = String(t.suffix(50)).lowercased()
        for token in ["http", "www.", ".com", ".org", ".cn", ".html", "github", "gov.", "/"] {
            if tail.contains(token) { return true }
        }
        return false
    }
    private static func isOpen(_ text: String) -> Bool { !endsComplete(text) }

    /// A block that resumes a sentence (a footnote continuation) starts lowercase, a
    /// URL, or a non-Latin (e.g. CJK) character — not a capitalised new paragraph,
    /// a header, table, blockquote, image, or rule.
    private static func isContinuationStart(_ b: String) -> Bool {
        let t = b.trimmingCharacters(in: .whitespaces)
        guard let c = t.first else { return false }
        if "#|>*".contains(c) || t.hasPrefix("![") { return false }
        return !(c.isASCII && c.isUppercase)
    }

    private static func collapseBlankRuns(_ s: String) -> String {
        guard let re = try? NSRegularExpression(pattern: "\n{3,}") else { return s }
        let range = NSRange(s.startIndex..., in: s)
        return re.stringByReplacingMatches(in: s, range: range, withTemplate: "\n\n")
    }

    // MARK: - Helpers

    private static func sanitized(_ name: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let cleaned = String(name.map { allowed.contains($0) ? $0 : "_" })
        return cleaned.isEmpty ? "document" : cleaned
    }

    private static func pythonExecutable() -> URL? {
        let py = URL(fileURLWithPath: NSHomeDirectory() + "/.pilcrow-pdf-venv/bin/python")
        return FileManager.default.isExecutableFile(atPath: py.path) ? py : nil
    }

    @MainActor
    static func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t import via PyMuPDF4LLM"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
