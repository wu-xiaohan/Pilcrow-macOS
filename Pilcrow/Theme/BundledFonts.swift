// SPDX-License-Identifier: GPL-3.0-only
//  BundledFonts.swift
//  Pilcrow for macOS
//
//  Registers the bundled OFL fonts with the process so they're available by
//  family name (Lora, Shantell Sans, Noto Sans SC, Ma Shan Zheng).

import AppKit
import CoreText

enum BundledFonts {
    static func register() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else { return }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
