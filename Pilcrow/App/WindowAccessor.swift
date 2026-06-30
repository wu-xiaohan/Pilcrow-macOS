// SPDX-License-Identifier: GPL-3.0-only
//  WindowAccessor.swift
//  Pilcrow for macOS
//
//  Makes the hosting NSWindow's titlebar blend with the editor (transparent,
//  no separator, matching background) and auto-hides the toolbar in full screen
//  (revealed on hover).

import SwiftUI
import AppKit
import ObjectiveC

struct WindowAccessor: NSViewRepresentable {
    var backgroundColor: NSColor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(to: view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: view.window) }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = backgroundColor
        TitlebarController.install(on: window)
    }
}

/// Window delegate that auto-hides the toolbar in full screen, forwarding every
/// other delegate message to the window's original delegate.
final class TitlebarController: NSObject, NSWindowDelegate {
    private weak var previous: NSWindowDelegate?
    private static var key: UInt8 = 0

    static func install(on window: NSWindow) {
        if window.delegate is TitlebarController { return }
        let controller = (objc_getAssociatedObject(window, &key) as? TitlebarController) ?? TitlebarController()
        controller.previous = window.delegate
        window.delegate = controller
        objc_setAssociatedObject(window, &key, controller, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func window(_ window: NSWindow,
                willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
        var options = proposedOptions
        // autoHideToolbar requires fullScreen + autoHideMenuBar to be set too.
        options.insert(.fullScreen)
        options.insert(.autoHideMenuBar)
        options.insert(.autoHideToolbar)
        if let forwarded = previous?.window?(window, willUseFullScreenPresentationOptions: proposedOptions) {
            options.formUnion(forwarded)
        }
        return options
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return previous?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        (previous?.responds(to: aSelector) == true) ? previous : nil
    }
}
