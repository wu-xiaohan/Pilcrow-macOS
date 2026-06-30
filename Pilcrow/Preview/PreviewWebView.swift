// SPDX-License-Identifier: GPL-3.0-only
//  PreviewWebView.swift
//  Pilcrow for macOS

import SwiftUI
import WebKit

struct PreviewWebView: NSViewRepresentable {
    var html: String
    var backgroundColor: NSColor

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")  // let body bg show, avoid white flash
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        // Load from a temp file so the page can read bundled @font-face files.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("apostrophe-preview.html")
        do {
            try html.data(using: .utf8)?.write(to: url)
            webView.loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        } catch {
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var lastHTML: String? }
}
