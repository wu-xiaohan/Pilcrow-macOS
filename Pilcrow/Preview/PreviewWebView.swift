// SPDX-License-Identifier: GPL-3.0-only
//  PreviewWebView.swift
//  Pilcrow for macOS

import SwiftUI
import WebKit

struct PreviewWebView: NSViewRepresentable {
    var html: String
    var backgroundColor: NSColor
    /// Folder of the open document, so relative image paths resolve to it.
    var baseDirectory: URL?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator.handler, forURLScheme: PreviewScheme.name)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")  // let body bg show, avoid white flash
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.handler.documentDirectory = baseDirectory
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        // Load on the document origin so relative resources (images next to the
        // .md) resolve to the document's folder via the scheme handler.
        webView.loadHTMLString(html, baseURL: URL(string: PreviewScheme.docOrigin + "/"))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator {
        let handler = PreviewSchemeHandler()
        var lastHTML: String?
    }
}

/// Custom scheme + origins for the preview. The page is loaded on `docOrigin`, so
/// document-relative resources resolve there; bundled fonts use `fontOrigin`.
enum PreviewScheme {
    static let name = "pcfont"
    static let docOrigin = "\(name)://doc"
    static let fontOrigin = "\(name)://font"
}

/// Serves the preview's local resources through a custom URL scheme — WKWebView
/// blocks `file://` subresources (fonts and images) from a page, which left the
/// preview without its chosen font and without document-relative images:
///   `pcfont://font/<Name>.ttf` → a bundled font
///   `pcfont://doc/<rel/path>`  → a file relative to the open document's folder
/// Responses carry a permissive CORS header so the cross-origin font fetch is allowed.
final class PreviewSchemeHandler: NSObject, WKURLSchemeHandler {
    /// The folder of the currently open document (nil for unsaved documents).
    var documentDirectory: URL?

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let data = body(for: url) else {
            task.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": Self.mimeType(forExtension: url.pathExtension),
                "Content-Length": "\(data.count)",
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": url.host == "font" ? "max-age=31536000" : "no-cache",
            ])!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private func body(for url: URL) -> Data? {
        switch url.host {
        case "font":
            let base = url.deletingPathExtension().lastPathComponent
            guard !base.isEmpty,
                  let fileURL = Bundle.main.url(forResource: base, withExtension: "ttf") else { return nil }
            return try? Data(contentsOf: fileURL)
        case "doc":
            guard let dir = documentDirectory else { return nil }
            let rel = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
            guard !rel.isEmpty else { return nil }
            let fileURL = dir.appendingPathComponent(rel).standardizedFileURL
            // Path-traversal guard: only serve files inside the document's folder.
            let root = dir.standardizedFileURL.path
            guard fileURL.path == root || fileURL.path.hasPrefix(root + "/") else { return nil }
            return try? Data(contentsOf: fileURL)
        default:
            return nil
        }
    }

    private static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "png":          return "image/png"
        case "jpg", "jpeg":  return "image/jpeg"
        case "gif":          return "image/gif"
        case "webp":         return "image/webp"
        case "svg":          return "image/svg+xml"
        case "bmp":          return "image/bmp"
        case "heic":         return "image/heic"
        case "ttf":          return "font/ttf"
        case "otf":          return "font/otf"
        default:             return "application/octet-stream"
        }
    }
}
