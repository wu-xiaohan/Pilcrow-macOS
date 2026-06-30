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
        // Serve bundled @font-face files via a custom scheme; WKWebView refuses to
        // load file:// fonts cross-origin, which left the preview unstyled.
        config.setURLSchemeHandler(BundledFontSchemeHandler(),
                                   forURLScheme: BundledFontSchemeHandler.scheme)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")  // let body bg show, avoid white flash
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        // Load the page on the same origin as the fonts so @font-face is same-origin.
        webView.loadHTMLString(html, baseURL: URL(string: BundledFontSchemeHandler.origin + "/"))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var lastHTML: String? }
}

/// Serves the app's bundled `.ttf` fonts to the preview web view through a custom
/// URL scheme (`pcfont:///Lora.ttf`). WKWebView blocks `file://` font loads from a
/// page (fonts are CORS-checked and a file page has a null origin), so the preview
/// otherwise fell back to the system font. The response carries a permissive CORS
/// header so the cross-origin font fetch is allowed.
final class BundledFontSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "pcfont"
    /// Page and fonts share this origin, so the @font-face fetch is same-origin.
    static let origin = "\(scheme)://fonts"

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else {
            task.didFailWithError(URLError(.badURL)); return
        }
        let base = url.deletingPathExtension().lastPathComponent   // "Lora"
        guard !base.isEmpty,
              let fileURL = Bundle.main.url(forResource: base, withExtension: "ttf"),
              let data = try? Data(contentsOf: fileURL) else {
            task.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "font/ttf",
                "Content-Length": "\(data.count)",
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "max-age=31536000",
            ])!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
