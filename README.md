# Pilcrow

A native macOS distraction-free Markdown editor, built in SwiftUI + AppKit/TextKit.
Pilcrow is a ground-up rewrite of [Apostrophe](https://gitlab.gnome.org/World/apostrophe)
(the GNOME/GTK editor) — a personal GPLv3 fork whose one divergence from upstream is an
adjustable editor column width (*characters per line*).

> Status: **feature-complete.** Builds Debug + Release, full XCTest suite passing.
> See [`docs/SPEC.md`](docs/SPEC.md) for the original plan, [`docs/SPEC-review.md`](docs/SPEC-review.md)
> and [`docs/FEATURE-GAP.md`](docs/FEATURE-GAP.md) for the parity analyses.

## Install (no Apple Developer account needed)

Pilcrow is distributed as an **ad-hoc-signed** app — free to build and share, but
not notarized by Apple, so Gatekeeper needs a one-time override the first time you
open it.

1. Download `Pilcrow.zip` from the [Releases](../../releases) page and unzip it.
2. Move **Pilcrow.app** to `/Applications`.
3. **First launch** — pick whichever works on your macOS version:
   - **Right-click** (or Control-click) the app → **Open** → **Open** in the dialog; or
   - Open it once, get blocked, then go to **System Settings → Privacy & Security**
     and click **Open Anyway**; or
   - From Terminal, clear the quarantine flag:
     ```sh
     xattr -dr com.apple.quarantine /Applications/Pilcrow.app
     ```

After the first approval it opens normally. The app is **fully self-contained** —
`pandoc` and `typst` (used for preview, PDF, and export) are bundled inside, so
nothing else needs to be installed.

> **Apple Silicon (M-series) required** for the prebuilt download — the bundled
> `pandoc`/`typst` are arm64. On an Intel Mac, build from source (below): the build
> bundles whatever architecture your Homebrew `pandoc`/`typst` are.

## Features

- **Editor** — centered, width-constrained monospace column with the dynamic font ramp;
  live Markdown syntax highlighting (23 ported regexes); smart editing (auto-pair, list
  continuation, Tab/Shift-Tab list indent, format toggles); **Bionic reading**.
- **Format menu + bottom-left collapsible toolbar** — headings, lists, checklist,
  blockquote, code block, horizontal rule, link, image.
- **Live preview** — pandoc → WKWebView, theme-matched CSS, half/full/half-height layouts;
  honors the per-script fonts and column width.
- **Modes** — focus mode (sentence dimming + typewriter scroll), Hemingway, fullscreen
  with auto-hiding header.
- **Color themes** — System / White / Dark / Sepia (default) + six soft palettes, a
  custom "Pick Your Color" window, and two favourites pinned to the menu (with swatches).
- **Per-script fonts** — independent Latin + CJK fonts (bundled Lora, Shantell Sans,
  Noto Sans SC, Ma Shan Zheng), applied in editor and preview.
- **Pomodoro timer** — header countdown + popover (manual durations, Skip), notifications.
- **Background sounds** — piano / nature / your-own-music playlists, Pomodoro-synced with
  calm break music; click = play, double-click = next, triple-click = volume; volume + a
  managed music list live in Preferences.
- **Stats bar**, native **Find/Replace**, **export** (19 pandoc formats + Typst PDF + Copy HTML).
- **Data safety** — robust encoding detection, external file-change detection with reload,
  and crash-recovery snapshots.

## Documentation

- [`tutorial.md`](tutorial.md) — how to write Markdown (headings, lists, links, tables…).
- [`instruction.md`](instruction.md) — how to use the app: what every icon means, the
  writing modes, themes, export, and the full keyboard-shortcut list.

## Build from source

### Requirements

- macOS 14 (Sonoma) or later, Xcode 26+ (full Xcode, not just Command Line Tools)
- Homebrew tools:
  ```sh
  brew install xcodegen pandoc typst
  ```

If `git`/`xcrun` error with *"invalid active developer path"* or builds report the
license isn't accepted (one-time, needs your password):

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

### Run

```sh
./scripts/dev-build.sh        # bundles tools, generates the project, builds Debug, launches
```

Or open it in Xcode:

```sh
./scripts/prepare-assets.sh   # bundle pandoc/typst into Resources/Tools (first time)
xcodegen generate             # writes Pilcrow.xcodeproj (git-ignored)
open Pilcrow.xcodeproj         # ⌘R to run, ⌘U for tests
```

## Package & share a release

```sh
./scripts/build-release.sh    # → build/Pilcrow.app and build/Pilcrow.zip (ad-hoc signed)
```

Then create a [GitHub Release](../../releases) and upload `build/Pilcrow.zip`. Recipients
follow the [Install](#install-no-apple-developer-account-needed) steps above — no Apple
account, no notarization required on either side.

`.github/workflows/pilcrow-macos-release.yml` automates this: push a **`macos-v0.1.0`**
(or `v0.1.0`) tag, or run the workflow manually, and CI builds on an Apple-Silicon runner
and attaches `Pilcrow.zip` to that release.

### Optional: notarized Developer ID build

If you *do* have a paid Apple Developer account and want zero Gatekeeper prompts for users:

```sh
DEVELOPER_ID_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  DEVELOPMENT_TEAM=TEAMID \
  NOTARY_PROFILE=pilcrow-notary \
  ./scripts/build-release.sh
```

Notes:
- The app is **not sandboxed** (it spawns the bundled `pandoc`/`typst`); distribute via
  Developer ID + notarization, not the App Store, or redesign the converters as an
  XPC/helper for a sandboxed MAS variant.
- `Resources/Tools/` (the bundled `pandoc`/`typst`/`libgmp`) is **git-ignored** — `pandoc`
  alone exceeds GitHub's 100 MB file limit. `scripts/prepare-assets.sh` recreates it from
  your Homebrew install (the build scripts call it automatically).
- The app icon comes from `data/icon-mac/inkwen_1024.png`.

## Project layout

```
pilcrow-macos/
  project.yml                 # XcodeGen project definition (→ Pilcrow.xcodeproj)
  scripts/                    # prepare-assets / dev-build / build-release
  Pilcrow/
    App/                      # @main app (PilcrowApp), scenes, commands
    Document/                 # MarkdownDocument, encoding/recovery/change-monitor
    Editor/                   # NSTextView host (EditorView, PilcrowTextView)
    Highlight/                # MarkdownPatterns (ported regexes), ThemePalette
    Stats/ Settings/ Theme/   # stats engine, settings, color themes
    Preview/ Convert/ Find/   # WKWebView preview, pandoc/typst export, find & replace
    Pomodoro/ Sounds/         # timer + background-sound player
    Resources/                # Info.plist, entitlements, Assets, Fonts, Sounds, Tools*
  Tests/                      # XCTest unit tests
  docs/                       # SPEC.md, SPEC-review.md, FEATURE-GAP.md
```
*`Resources/Tools` is generated by `prepare-assets.sh`, not committed.

## Provenance

Upstream Apostrophe is GPLv3 (Manuel Genovés, Wolf Vollprecht, et al.). Pilcrow follows
the same license; the Swift sources cite the upstream Python modules they port.
