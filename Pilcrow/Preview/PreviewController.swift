// SPDX-License-Identifier: GPL-3.0-only
//  PreviewController.swift
//  Pilcrow for macOS
//
//  Debounces Markdown→HTML conversions and publishes themed HTML for the
//  preview web view. Conversions run off the main thread and coalesce to the
//  latest request.

import SwiftUI

@MainActor
final class PreviewController: ObservableObject {
    @Published var html: String = ""
    @Published var errorMessage: String?

    private var task: Task<Void, Never>?

    func request(markdown: String, theme: EditorTheme, charactersPerLine: Int, bionic: Bool,
                 latinFont: String, cjkFont: String, debounce: Bool = true) {
        task?.cancel()
        let css = PreviewCSS.stylesheet(for: theme, charactersPerLine: charactersPerLine,
                                        latinFont: latinFont, cjkFont: cjkFont)
        task = Task { [weak self] in
            if debounce {
                try? await Task.sleep(nanoseconds: 150_000_000)
                if Task.isCancelled { return }
            }
            do {
                let body = try await Task.detached(priority: .userInitiated) {
                    try PandocRunner.markdownToHTML(markdown)
                }.value
                if Task.isCancelled { return }
                self?.html = Self.inject(css: css, bionic: bionic, into: body)
                self?.errorMessage = nil
            } catch is CancellationError {
                // superseded
            } catch {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    private static func inject(css: String, bionic: Bool, into html: String) -> String {
        var head = "<style>\n\(css)\n</style>\n<script>\n\(anchorScript)\n</script>"
        if bionic { head += "\n<script>\n\(bionicScript)\n</script>" }
        if let range = html.range(of: "</head>") {
            return html.replacingCharacters(in: range, with: "\(head)\n</head>")
        }
        return head + html
    }

    /// Smooth in-page scrolling for `#` anchor links (footnote jump navigation), so
    /// they work even though the preview is loaded via a custom URL scheme.
    private static let anchorScript = #"""
    document.addEventListener('click', function (e) {
      var a = e.target.closest ? e.target.closest('a[href^="#"]') : null;
      if (!a) return;
      var el = document.getElementById(a.getAttribute('href').slice(1));
      if (el) { e.preventDefault(); el.scrollIntoView({ behavior: 'smooth', block: 'center' }); }
    });
    """#

    /// Bionic reading for the preview: bolds the leading portion of each word,
    /// skipping code/pre. Builds DOM text nodes (no innerHTML) to stay safe.
    private static let bionicScript = #"""
    (function () {
      function run() {
        var skip = { PRE: 1, CODE: 1, SCRIPT: 1, STYLE: 1, TEXTAREA: 1 };
        var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
        var targets = [];
        while (walker.nextNode()) {
          var n = walker.currentNode;
          if (!n.parentNode || skip[n.parentNode.nodeName]) continue;
          if (!/\p{L}/u.test(n.nodeValue)) continue;
          targets.push(n);
        }
        targets.forEach(function (n) {
          var text = n.nodeValue, frag = document.createDocumentFragment();
          var re = /\p{L}+/gu, last = 0, m;
          while ((m = re.exec(text))) {
            if (m.index > last) frag.appendChild(document.createTextNode(text.slice(last, m.index)));
            var w = m[0], k = w.length <= 3 ? w.length : Math.ceil(w.length * 0.4);
            var b = document.createElement('b');
            b.appendChild(document.createTextNode(w.slice(0, k)));
            frag.appendChild(b);
            if (k < w.length) frag.appendChild(document.createTextNode(w.slice(k)));
            last = m.index + w.length;
          }
          if (last < text.length) frag.appendChild(document.createTextNode(text.slice(last)));
          n.parentNode.replaceChild(frag, n);
        });
      }
      if (document.readyState !== 'loading') { run(); } else { document.addEventListener('DOMContentLoaded', run); }
    })();
    """#
}
