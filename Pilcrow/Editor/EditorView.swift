// SPDX-License-Identifier: GPL-3.0-only
//  EditorView.swift
//  Pilcrow for macOS

import SwiftUI
import AppKit

struct EditorView: View {
    @Binding var text: String
    var fileURL: URL?

    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage(SettingsKey.colorScheme) private var colorSchemeRaw = AppColorScheme.system.rawValue
    @AppStorage(SettingsKey.biggerText) private var biggerText = false
    @AppStorage(SettingsKey.spellcheck) private var spellcheck = true
    @AppStorage(SettingsKey.charactersPerLine) private var charactersPerLine = AppDefaults.charactersPerLineDefault
    @AppStorage(SettingsKey.previewActive) private var previewActive = false
    @AppStorage(SettingsKey.previewMode) private var previewModeRaw = PreviewMode.halfWidth.rawValue
    @AppStorage(SettingsKey.focusMode) private var focusMode = false
    @AppStorage(SettingsKey.hemingwayMode) private var hemingwayMode = false
    @AppStorage(SettingsKey.bionicReading) private var bionicReading = false
    @AppStorage(SettingsKey.customBackground) private var customBackground = "#FBF1E6"
    @AppStorage(SettingsKey.favouriteThemes) private var favouriteThemes = "sepia,sage"
    @AppStorage(SettingsKey.latinFont) private var latinFont = "Default"
    @AppStorage(SettingsKey.cjkFont) private var cjkFont = "Default"
    @AppStorage("didShowWelcome") private var didShowWelcome = false
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openDocument) private var openDocument

    @StateObject private var preview = PreviewController()
    @StateObject private var statsController = StatsController()
    @StateObject private var external = ExternalChangeMonitor()
    @StateObject private var recovery = RecoveryStore()
    @State private var showingExport = false
    @State private var confirmReload = false

    private var scheme: AppColorScheme { AppColorScheme(rawValue: colorSchemeRaw) ?? .sepia }
    private var theme: EditorTheme {
        EditorTheme.resolve(scheme, systemIsDark: systemColorScheme == .dark, customHex: customBackground)
    }
    private var previewMode: PreviewMode { PreviewMode(rawValue: previewModeRaw) ?? .halfWidth }
    private var favouriteSchemes: [AppColorScheme] {
        favouriteThemes.split(separator: ",").compactMap { AppColorScheme(rawValue: String($0)) }.prefix(2).map { $0 }
    }

    var body: some View {
        content
            .background(Color(nsColor: theme.background))
            .background(WindowAccessor(backgroundColor: theme.background))
            .preferredColorScheme(preferredColorScheme)
            .frame(minWidth: 480, minHeight: 320)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomBar(stats: statsController.stats, background: Color(nsColor: theme.background))
            }
            .safeAreaInset(edge: .top, spacing: 0) { topBanner }
            .toolbar { toolbarContent }
            .toolbarBackground(Color(nsColor: theme.background), for: .windowToolbar)
            .sheet(isPresented: $showingExport) {
                ExportView(text: text,
                           defaultName: fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled",
                           baseURL: fileURL?.deletingLastPathComponent())
            }
            .onChange(of: text) { _, _ in updatePreview(); statsController.update(text); recovery.note(text) }
            .onChange(of: colorSchemeRaw) { _, _ in updatePreview() }
            .onChange(of: systemColorScheme) { _, _ in updatePreview() }
            .onChange(of: previewActive) { _, active in if active { updatePreview() } }
            .onChange(of: previewModeRaw) { _, _ in updatePreview() }
            .onChange(of: charactersPerLine) { _, _ in updatePreview() }
            .onChange(of: bionicReading) { _, _ in updatePreview() }
            .onChange(of: latinFont) { _, _ in updatePreview() }
            .onChange(of: cjkFont) { _, _ in updatePreview() }
            .onChange(of: fileURL) { _, url in external.start(url: url); recovery.begin(url: url, currentText: text) }
            .onAppear { updatePreview(); statsController.update(text); external.start(url: fileURL); recovery.begin(url: fileURL, currentText: text); showWelcomeIfNeeded() }
            .onDisappear { external.stop() }
    }

    @ViewBuilder private var topBanner: some View {
        if let recovered = recovery.pendingRestore {
            bannerRow(icon: "clock.arrow.circlepath", tint: .blue,
                      message: "Recovered unsaved changes from a previous session.",
                      primary: ("Restore", false, { text = recovered; recovery.pendingRestore = nil }),
                      secondary: ("Discard", { recovery.discard() }))
        } else if let disk = external.diskContent, disk != text {
            bannerRow(icon: "exclamationmark.triangle.fill", tint: .yellow,
                      message: "This file was changed by another app.",
                      primary: ("Reload", true, { confirmReload = true }),
                      secondary: ("Keep Mine", { external.dismiss() }))
                .confirmationDialog("Replace your version with the file on disk? Unsaved changes will be lost.",
                                    isPresented: $confirmReload, titleVisibility: .visible) {
                    Button("Reload", role: .destructive) {
                        if let disk = external.diskContent { text = disk }
                        external.dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
        }
    }

    private func bannerRow(icon: String, tint: Color, message: String,
                           primary: (title: String, destructive: Bool, action: () -> Void),
                           secondary: (title: String, action: () -> Void)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(message)
            Spacer()
            Button(secondary.title, action: secondary.action)
            Button(primary.title, role: primary.destructive ? .destructive : nil, action: primary.action)
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    @ViewBuilder private var content: some View {
        if previewActive {
            switch previewMode {
            case .halfWidth:
                HSplitView {
                    editor.frame(minWidth: 280)
                    previewPane.frame(minWidth: 280)
                }
            case .halfHeight:
                VSplitView {
                    editor.frame(minHeight: 160)
                    previewPane.frame(minHeight: 160)
                }
            case .fullWidth, .windowed:
                previewPane
            }
        } else {
            editor
        }
    }

    private var editor: some View {
        MarkdownTextView(text: $text,
                         theme: theme,
                         charactersPerLine: charactersPerLine,
                         biggerText: biggerText,
                         spellcheck: spellcheck,
                         focusMode: focusMode,
                         hemingwayMode: hemingwayMode,
                         bionicReading: bionicReading,
                         latinFamily: latinFont,
                         cjkFamily: cjkFont,
                         fileURL: fileURL)
    }

    private func swatch(for scheme: AppColorScheme) -> Image {
        let bg = EditorTheme.resolve(scheme, systemIsDark: systemColorScheme == .dark,
                                     customHex: customBackground).background
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
            bg.setFill(); path.fill()
            NSColor.separatorColor.setStroke(); path.lineWidth = 0.5; path.stroke()
            return true
        }
        image.isTemplate = false
        return Image(nsImage: image)
    }

    private func themeLabel(_ scheme: AppColorScheme) -> String {
        scheme.label + (colorSchemeRaw == scheme.rawValue ? "  ✓" : "")
    }

    private var previewPane: some View {
        PreviewWebView(html: preview.html, backgroundColor: theme.background,
                       baseDirectory: fileURL?.deletingLastPathComponent())
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showingExport = true } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export… (⇧⌘E)")
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
        ToolbarItem(placement: .primaryAction) {
            PomodoroToolbar()
        }
        ToolbarItem(placement: .primaryAction) {
            SoundsToolbar()
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Preview Layout", selection: $previewModeRaw) {
                    Text("Half Width").tag(PreviewMode.halfWidth.rawValue)
                    Text("Full Width").tag(PreviewMode.fullWidth.rawValue)
                    Text("Half Height").tag(PreviewMode.halfHeight.rawValue)
                }
            } label: {
                Label("Preview", systemImage: previewActive ? "sidebar.right" : "sidebar.squares.right")
            } primaryAction: {
                previewActive.toggle()
            }
            .help("Toggle preview (⇧⌘P); open the menu for layout")
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                ForEach(favouriteSchemes) { fav in
                    Button { colorSchemeRaw = fav.rawValue } label: {
                        Label { Text(themeLabel(fav)) } icon: { swatch(for: fav) }
                    }
                }
                Menu("Color Theme") {
                    ForEach(AppColorScheme.presets) { s in
                        Button { colorSchemeRaw = s.rawValue } label: {
                            Label { Text(themeLabel(s)) } icon: { swatch(for: s) }
                        }
                    }
                }
                Button("Pick Your Color…") { openWindow(id: "pick-color") }
                Divider()
                Toggle("Focus Mode", isOn: $focusMode)
                Toggle("Hemingway Mode", isOn: $hemingwayMode)
                Toggle("Bionic Reading", isOn: $bionicReading)
                Divider()
                Button("Markdown Tutorial") { openHelp(HelpDocs.tutorial) }
                Button("How to Use Pilcrow") { openHelp(HelpDocs.instruction) }
                Divider()
                SettingsLink { Text("Preferences…") }
            } label: {
                Label("Menu", systemImage: "ellipsis.circle")
            }
            .help("Menu")
        }
    }

    private func updatePreview() {
        guard previewActive else { return }
        preview.request(markdown: text, theme: theme,
                        charactersPerLine: charactersPerLine, bionic: bionicReading,
                        latinFont: latinFont, cjkFont: cjkFont)
    }

    /// Opens a bundled help doc (tutorial / instruction) in a new editor window.
    private func openHelp(_ resource: String) {
        guard let url = HelpDocs.openableURL(resource) else { return }
        Task { try? await openDocument(at: url) }
    }

    /// On the very first launch, open the instruction guide so new users see it.
    private func showWelcomeIfNeeded() {
        guard !didShowWelcome else { return }
        didShowWelcome = true
        openHelp(HelpDocs.instruction)
    }

    private var preferredColorScheme: ColorScheme? {
        scheme == .system ? nil : (theme.isDark ? .dark : .light)
    }
}
