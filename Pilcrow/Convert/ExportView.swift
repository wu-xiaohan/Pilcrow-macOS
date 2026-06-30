// SPDX-License-Identifier: GPL-3.0-only
//  ExportView.swift
//  Pilcrow for macOS
//
//  Export sheet: pick a format, set options, and write the file via pandoc.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExportView: View {
    let text: String
    let defaultName: String
    let baseURL: URL?
    @Environment(\.dismiss) private var dismiss

    @State private var selection: ExportFormat? = ExportFormat.all.first
    @State private var options = ExportOptions()
    @State private var isExporting = false
    @State private var error: String?

    private var format: ExportFormat { selection ?? ExportFormat.all[0] }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                List(ExportFormat.all, id: \.self, selection: $selection) { fmt in
                    Text(fmt.name).tag(fmt)
                }
                .frame(width: 230)

                Divider()

                Form { optionRows }
                    .formStyle(.grouped)
                    .frame(minWidth: 280)
            }

            Divider()
            footer
        }
        .frame(width: 620, height: 420)
    }

    @ViewBuilder private var optionRows: some View {
        Section("\(format.name)") {
            Toggle("Standalone document", isOn: $options.standalone)
            Toggle("Table of contents", isOn: $options.tableOfContents)
            Toggle("Number sections", isOn: $options.numberSections)
        }

        if format.hasPages {
            Section("Page") {
                Picker("Paper size", selection: $options.pageSizeLetter) {
                    Text("A4").tag(false)
                    Text("Letter").tag(true)
                }
            }
        }
        if format.hasSlides {
            Section("Slides") {
                Toggle("16:9 (widescreen)", isOn: $options.slideWide)
            }
        }
        if format.isHTML {
            Section("HTML") {
                Toggle("Self-contained (embed resources)", isOn: $options.htmlSelfContained)
            }
        }
        if format.hasSyntax {
            Section("Code") {
                Picker("Highlight style", selection: $options.syntaxStyle) {
                    Text("Default").tag(String?.none)
                    ForEach(Exporter.syntaxStyles, id: \.self) { Text($0).tag(String?.some($0)) }
                }
            }
        }
        if format.isPresentation {
            Section("Presentation") {
                Toggle("Incremental bullets", isOn: $options.incrementalBullets)
            }
        }
        if format.requiresTeXLive && !Exporter.teXLiveAvailable() {
            Section {
                Label("This format needs a TeX install (e.g. MacTeX). Try the Typst PDF instead.",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            if let error {
                Text(error).font(.callout).foregroundStyle(.red).lineLimit(2)
            }
            Spacer()
            Button("Copy HTML") { copyHTML() }
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Button("Export…") { runExport() }
                .keyboardShortcut(.defaultAction)
                .disabled(isExporting)
        }
        .padding(12)
    }

    private func runExport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(defaultName).\(format.ext)"
        if let baseURL { panel.directoryURL = baseURL }
        panel.canCreateDirectories = true
        if let type = UTType(filenameExtension: format.ext) { panel.allowedContentTypes = [type] }

        guard panel.runModal() == .OK, let url = panel.url else { return }
        isExporting = true
        error = nil
        let fmt = format, opts = options, body = text
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try Exporter.export(text: body, format: fmt, options: opts, to: url)
                }.value
                isExporting = false
                dismiss()
            } catch {
                self.error = error.localizedDescription
                isExporting = false
            }
        }
    }

    private func copyHTML() {
        do {
            let html = try Exporter.htmlForClipboard(text)
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(html, forType: .html)
            pb.setString(html, forType: .string)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
