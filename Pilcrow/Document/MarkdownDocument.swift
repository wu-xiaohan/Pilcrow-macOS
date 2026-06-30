// SPDX-License-Identifier: GPL-3.0-only
//  MarkdownDocument.swift
//  Pilcrow for macOS

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Declared in Info.plist (UTImportedTypeDeclarations).
    static let markdownText = UTType(importedAs: "net.daringfireball.markdown")
}

struct MarkdownDocument: FileDocument {
    var text: String

    init(text: String = "") { self.text = text }

    static var readableContentTypes: [UTType] { [.markdownText, .plainText] }
    static var writableContentTypes: [UTType] { [.markdownText, .plainText] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let decoded = EncodingDetector.decode(data) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        text = decoded.text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        SaveTracker.shared.record(text)   // so our own (auto)saves don't trip the change monitor
        return FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
