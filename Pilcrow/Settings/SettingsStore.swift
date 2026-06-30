// SPDX-License-Identifier: GPL-3.0-only
//  SettingsStore.swift
//  Pilcrow for macOS
//
//  Mirrors the upstream GSettings schema
//  `org.gnome.gitlab.somas.Apostrophe` (data/…/.gschema.xml) on UserDefaults.
//  Use the SettingsKey constants with @AppStorage in SwiftUI views.

import Foundation

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system, light, dark, sepia
    case lavenderMist = "lavender-mist"
    case periwinkle
    case softSky = "soft-sky"
    case softApricot = "soft-apricot"
    case warmSand = "warm-sand"
    case sage
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "White"
        case .dark: return "Dark"
        case .sepia: return "Sepia"
        case .lavenderMist: return "Lavender Mist"
        case .periwinkle: return "Periwinkle"
        case .softSky: return "Soft Sky"
        case .softApricot: return "Soft Apricot"
        case .warmSand: return "Warm Sand"
        case .sage: return "Sage"
        case .custom: return "Custom"
        }
    }

    /// Selectable presets (everything except the free-form custom color).
    static var presets: [AppColorScheme] {
        [.system, .light, .dark, .sepia, .lavenderMist, .periwinkle, .softSky, .softApricot, .warmSand, .sage]
    }
}

enum PrimaryStat: String, CaseIterable, Identifiable {
    case characters, words, sentences, paragraphs
    case readTime = "read_time"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .characters: return "Characters"
        case .words: return "Words"
        case .sentences: return "Sentences"
        case .paragraphs: return "Paragraphs"
        case .readTime: return "Reading Time"
        }
    }
}

enum PreviewMode: String, CaseIterable, Identifiable {
    case fullWidth = "full-width"
    case halfWidth = "half-width"
    case halfHeight = "half-height"
    case windowed
    var id: String { rawValue }
}

enum PreviewSecurity: String, CaseIterable, Identifiable {
    case ask
    case alwaysRestricted = "always-restricted"
    case alwaysUnrestricted = "always-unrestricted"
    var id: String { rawValue }
}

/// UserDefaults keys (kept identical to the upstream GSettings key names).
enum SettingsKey {
    static let colorScheme = "color-scheme"
    static let spellcheck = "spellcheck"
    static let syncScroll = "sync-scroll"
    static let inputFormat = "input-format"
    static let autohideHeaderbar = "autohide-headerbar"
    static let statDefault = "stat-default"
    static let charactersPerLine = "characters-per-line"   // fork: range 40–160
    static let hemingwayMode = "hemingway-mode"
    static let hemingwayToastCount = "hemingway-toast-count"
    static let focusMode = "focus-mode"   // runtime toggle (not persisted upstream)
    static let bionicReading = "bionic-reading"   // macOS addition
    static let customBackground = "custom-background"   // hex for the custom theme
    static let favouriteThemes = "favourite-themes"     // up to 2 comma-separated theme ids
    static let latinFont = "latin-font"
    static let cjkFont = "cjk-font"
    static let previewMode = "preview-mode"
    static let previewSecurity = "preview-security"
    static let previewActive = "preview-active"
    static let biggerText = "bigger-text"
    static let toolbarActive = "toolbar-active"
    static let autosavePeriod = "autosave-period"
}

enum AppDefaults {
    /// Fork change: the editor column width is user-adjustable within this range.
    static let charactersPerLineRange = 40.0...160.0
    static let charactersPerLineDefault = 66

    static func register() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.colorScheme: AppColorScheme.sepia.rawValue,   // Sepia is the default
            SettingsKey.customBackground: "#FBF1E6",
            SettingsKey.favouriteThemes: "sepia,sage",
            SettingsKey.latinFont: "Default",
            SettingsKey.cjkFont: "Default",
            SettingsKey.spellcheck: true,
            SettingsKey.syncScroll: true,
            SettingsKey.inputFormat: "markdown",
            SettingsKey.autohideHeaderbar: true,
            SettingsKey.statDefault: PrimaryStat.words.rawValue,
            SettingsKey.charactersPerLine: charactersPerLineDefault,
            SettingsKey.hemingwayMode: false,
            SettingsKey.hemingwayToastCount: 0,
            SettingsKey.previewMode: PreviewMode.halfWidth.rawValue,
            SettingsKey.bionicReading: false,
            SettingsKey.previewSecurity: PreviewSecurity.ask.rawValue,
            SettingsKey.previewActive: false,
            SettingsKey.biggerText: false,
            SettingsKey.toolbarActive: false,
            SettingsKey.autosavePeriod: 5,
        ])
    }
}
