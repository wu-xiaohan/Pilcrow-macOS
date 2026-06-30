# Apostrophe for macOS — Native Rewrite Specification

> Status: Architecture draft v1. Source of truth for the build. All upstream behavioral claims are drawn from the GNOME/GTK4 Apostrophe `main` branch; items flagged in §7 must be re-verified against the user's local fork once its source files are populated (they are currently 0-byte stubs).

---

## 1. Product Summary

**Apostrophe for macOS** is a distraction-free Markdown editor rebuilt as a true Mac-native application. It preserves the upstream philosophy — a clean, centered, width-constrained writing surface with chrome that gets out of the way — while feeling indistinguishable from a first-party Apple app.

**Design ethos**
- **Writing first.** A single centered text column with a constrained measure (default ~66 characters/line), generous margins, a quality reading font, and auto-hiding chrome. Everything optional (preview, stats, toolbar) collapses away.
- **Calm, focused.** Focus mode (dim all but the current sentence), typewriter scrolling, optional Hemingway (no-delete) mode, and immersive fullscreen.
- **Native, not ported.** No GTK look-alikes. Standard macOS conventions throughout.

**What "native" means here**
- **Document-based app** built on `NSDocument` (AppKit) / `DocumentGroup` (SwiftUI) — free Open/Save/Save-As/Duplicate, Open Recent, autosave-in-place, Versions/Time-Machine restore, and document dirty tracking.
- **Standard macOS menu bar** (App / File / Edit / Format / View / Window / Help) instead of a hamburger menu. All actions live as menu items with standard `⌘`-based shortcuts.
- **Standard window chrome.** Traffic-light buttons, a unified/transparent title bar that can hide in fullscreen, native fullscreen (`⌃⌘F`), and native split views for preview layouts.
- **System appearance.** Follows Light/Dark automatically via `NSApp.effectiveAppearance`; adds a custom Sepia theme. Honors Increase Contrast and Reduce Motion accessibility settings.
- **Native text behaviors.** `NSSpellChecker` continuous spell/grammar checking, the system Find bar, system services, Dictionary lookup (`DCSCopyTextDefinition`), drag-and-drop, and full `NSUndoManager` support.
- **Distribution.** Hardened-runtime, Developer ID-signed and notarized `.app` (direct download); Mac App Store as a later option. Deployment target macOS 14 (Sonoma)+.

**Tech stack**
- **SwiftUI** for app shell, Settings scene, dialogs, toolbars, and layout chrome.
- **AppKit + TextKit 2** (`NSTextView` wrapped in `NSViewRepresentable`) for the editor — required for precise control of margins, focus dimming, typewriter scroll, and regex-driven attribute styling.
- **WKWebView** for live HTML preview.
- **Bundled `pandoc`** (and `typst`) invoked via `Process` for preview conversion and export.

---

## 2. Feature Inventory (Parity Checklist)

Priority key: **M** = must-have, **S** = should-have, **N** = nice-to-have.

### 2.1 Editor surface
| Feature | Pri | Notes |
|---|---|---|
| Centered, width-constrained text column (chars-per-line, default 66) | M | Dynamic horizontal insets; recompute on layout. |
| Dynamic font sizing by available width | M | Pick from a size ramp (~14–24pt) based on column width. |
| "Bigger text" relative bump | S | Boolean preference. |
| Bundled reading fonts (Fira Sans / Fira Mono or substitutes) | S | Ship in app bundle; license-check. |
| Auto-hiding header/toolbar/stats while typing | S | Hide on keystroke, reveal on mouse-move / idle / search open. Suppress hiding in narrow window. |
| Native fullscreen (immersive) | M | Hide title bar + accessory bars in fullscreen. |
| Adaptive wide/compact toolbar layout | N | `ViewThatFits` / toolbar overflow at a width breakpoint. |
| Drag-and-drop: drop images → insert Markdown; drop `.md` → open | N | `NSDraggingDestination` / `.dropDestination`. Confirm fork behavior. |

### 2.2 Highlighting & smart editing
| Feature | Pri | Notes |
|---|---|---|
| Live regex-driven Markdown highlighting (no grammar engine) | M | ~24 patterns ported to `NSRegularExpression`; applied as attribute runs. |
| Headings — ATX (`#`..`######`) + Setext (`===`/`---`) | M | Bold, per-level scale, hanging markers via paragraph indent. |
| Bold / Italic / Bold-italic / Strikethrough (`*` and `_`) | M | Font traits + strikethrough; optionally dim delimiters. |
| Inline code + fenced code blocks (` ``` `/`~~~`) | M | Monospace, inline background, block background + indent. |
| Links, autolinks, bare URLs, images | M | Color link text; dim url/title; optional clickable link attr. |
| Blockquotes | S | Indent + left bar + dim. |
| Lists: unordered, ordered, GFM checklists | M | Shared regexes drive styling + smart-edit. |
| Tables, horizontal rules, math (`$`/`$$`), footnotes, YAML frontmatter | S | Tables: no-wrap/clip; rules centered; math/footnote ranges tappable; frontmatter dimmed. |
| HTML comments / display-math block as distinct categories | N | Not confirmed upstream — verify, add if desired. |
| Auto-pair brackets/quotes `() [] {} "" <>` | M | Insert close char; step over duplicate close. |
| List auto-continue on Return (+ ordered renumber) | M | Empty item removes marker. |
| Tab / Shift-Tab list indent cycling | M | Maintain indent hierarchy; cycle bullet symbol. |
| Format toggling/wrapping (bold/italic/etc., toggle off if wrapped) | M | Empty selection inserts marker + selected placeholder. |
| Heading level cycle (1→2→3) | S | Preserve indentation. |
| Table inserter (hover grid → Markdown pipe table) | S | `NSPopover` grid; splice padded table. |
| Inline preview popover (⌘/⌃-click: image / math / link / footnote / word) | S | `NSPopover` at glyph rect; math via SwiftMath; word via Dictionary Services. |
| Debounced re-highlight + grouped undo | S | Coalesced `DispatchWorkItem`; per-paragraph rescan; `NSUndoManager` grouping. |
| Spell check (continuous), auto-off in focus mode | S | `NSSpellChecker`. |

### 2.3 Preview
| Feature | Pri | Notes |
|---|---|---|
| Live Markdown→HTML preview (Pandoc) | M | Background convert, coalesce to latest, crossfade on reload. |
| WKWebView renderer | M | `loadHTMLString` with file base URL or custom scheme handler. |
| Layout modes: full-width, half-width (side-by-side), half-height (stacked), windowed, closed | S | Split views + separate `NSWindow` for windowed. |
| Bidirectional scroll sync (toggle) | S | `WKUserScript` + message handler + `evaluateJavaScript`; tolerance guards. |
| Math via MathJax (`--mathjax`) | M | Bundle MathJax/KaTeX offline. |
| Restricted/unrestricted preview security (ask / restricted / unrestricted) | S | Restricted → `markdown-raw_html`; detect raw HTML, warn before first render. |
| Theme-matched preview CSS (light/dark/sepia + high-contrast) | S | Inject CSS via `--css`; `--highlight-style=breezedark` in dark. |
| Markdown flavor selection (Pandoc / CommonMark / GFM / MultiMarkdown / strict) | S | Feeds preview + export. |

### 2.4 Export
| Feature | Pri | Notes |
|---|---|---|
| Quick export: PDF (Typst), HTML (self-contained), ODT | M | Bundled pandoc; PDF via bundled `typst` or `WKWebView.createPDF` fallback. |
| Advanced export (19 Pandoc targets via `formats.json`) | M | DOCX, ODT, EPUB3, reveal.js/DZSlides/Beamer, LaTeX, ConTeXt, RTF, MediaWiki, DokuWiki, Textile, RST, Texinfo, man, etc. |
| Export options: TOC, number sections, papersize, highlight style, slide ratio, incremental, reference-doc | S | SwiftUI form → assembled pandoc args. |
| TeX-dependent targets gated on detected system TeX | S | Mirror `requires_texlive`; disable rows if absent; steer to Typst PDF. |
| reveal.js multi-file (folder) export | N | Directory picker + copy bundled `reveal.js`. |
| Bundled templates / reference docs / Lua filter | S | `typst.typ`, `reference.docx/odt`, `relative_to_absolute.lua`. |
| Copy HTML to pasteboard | S | `NSPasteboard`. |
| Inline LaTeX → image (math preview) | N | Prefer SwiftMath/KaTeX-snapshot over bundling TeX. |

### 2.5 Focus / typewriter / writing modes
| Feature | Pri | Notes |
|---|---|---|
| Focus mode (dim all but current sentence) | M | Non-destructive rendering attributes; sentence via `NLTokenizer`. |
| Typewriter / centered smooth scrolling | M | Caret centered (or 32px band); cubic ease-out, distance-scaled duration. |
| Vertical centering in focus mode | M | Top/bottom inset = viewport height/2. |
| Hemingway (no-delete) mode | S | Block deletions; first-3-times explanatory banner. |
| Fullscreen | M | Native toggle. |

### 2.6 Stats
| Feature | Pri | Notes |
|---|---|---|
| Live counts: characters, words, sentences, paragraphs, reading time | M | Strip markup first; reuse exact regexes; CJK-aware word count. |
| Reading time @ 200 wpm, H:MM:SS | M | `words/200` minutes. |
| Selectable primary stat in bottom bar + popover with all metrics | S | Persist `statDefault`. |
| Selection-aware "X of Y" display | S | Localized plural strings. |

### 2.7 Find / Replace
| Feature | Pri | Notes |
|---|---|---|
| Find (in-document) | M | `NSTextFinder` or custom bar. |
| Find & Replace (single + all) | M | Replace-and-advance, replace-all. |
| Regex + case-sensitivity toggles | S | Map to `NSRegularExpression` options. |
| Prefill from selection; live highlight | S | Focus entry on open, restore focus on close. |

### 2.8 Themes / styles
| Feature | Pri | Notes |
|---|---|---|
| Light / Dark / System | M | `NSApp.appearance` / `nil` for system. |
| Sepia theme (bg #F9F3E9, fg #4F3915) | S | Custom palette for editor + preview CSS. |
| High-contrast variants | S | Respond to Increase Contrast. |
| Editor syntax palette per theme | S | Color struct keyed by theme. |
| Pride season easter egg (date-driven accent) | N | Swift enum mapping `Date` → season; no setting. |

### 2.9 Preferences
| Feature | Pri | Notes |
|---|---|---|
| Settings scene: autohide chrome, spellcheck, bigger text, input format, preview security | M | SwiftUI `Settings` + `@AppStorage`. |
| Additional keys: sync-scroll, stat-default, chars-per-line, toolbar-active, autosave-period, color-scheme | S | Full settings model. |
| Per-format help links | N | Open docs. |

### 2.10 File handling
| Feature | Pri | Notes |
|---|---|---|
| New / Open / Save / Save As / Close / Quit | M | `NSDocument` free. |
| Open Recent | M | `NSDocumentController.recentDocumentURLs`. |
| Encoding detection on open, UTF-8 on save | M | `String(contentsOf:usedEncoding:)` + fallback. |
| File associations (.md/.markdown/.txt) + CLI/Finder open | M | `CFBundleDocumentTypes` / UTType. |
| Reuse empty window; dedupe already-open file | S | Via `NSDocumentController`. |
| Autosave snapshots + crash/draft restore (5s) | S | Autosave-in-place + Versions, or custom snapshot + restore banner. |
| Unsaved-changes guard (Save/Don't Save/Cancel) | M | `NSDocument.canClose`. |
| Open bundled tutorial document | N | Help menu. |

### 2.11 Localization
| Feature | Pri | Notes |
|---|---|---|
| i18n via String Catalogs | N | Seed from existing gettext `po/`. |

---

## 3. GTK / Apostrophe → macOS Mapping

| Upstream component | macOS-native counterpart |
|---|---|
| `Adw.Application` (global state/actions/snapshots) | `App` (SwiftUI) + `NSApplicationDelegate`; `NSDocumentController` |
| `Adw.ApplicationWindow` / `MainWindow` (template, 30+ GActions) | `DocumentGroup` scene / `NSWindowController`; actions as menu `Commands` |
| `Editor` (Adw.Bin: scrolled textview + revealers) | SwiftUI container view hosting editor + `.safeAreaInset` accessory bars |
| `ApostropheTextView` (GtkSource.View) | `NSTextView` (TextKit 2) via `NSViewRepresentable` |
| `ApostropheTextBuffer` (GtkSource.Buffer) | `NSTextContentStorage` / `NSTextStorage` subclass |
| `text_view_markup_handler.py` (Pango tags) | `SyntaxHighlighter` applying attribute runs; focus dim via rendering/temporary attributes |
| `markup_regex.py` (`regex` module patterns) | `NSRegularExpression` (ICU) — patterns port nearly verbatim |
| `text_view_scroller.py` (frame-clock tick, ease_out_cubic) | `TypewriterScroller` via `CVDisplayLink`/`NSAnimationContext` over `NSClipView` |
| Focus mode dim (gray Pango tag) | `NSTextLayoutManager` rendering attributes / `NSLayoutManager` temporary attributes |
| `text_buffer` smart edits (auto-pair, list continue, indent) | `NSTextViewDelegate` `shouldChangeTextIn` + `insertNewline:`/`insertTab:` overrides |
| Hemingway `do_delete_range` override | Intercept `deleteBackward:`/`deleteForward:`/`cut:` + `shouldChangeText` |
| `WebKitGTK` `WebView` (preview) | `WKWebView` |
| Scroll-sync JS bridge | `WKUserScript` + `WKScriptMessageHandler` + `evaluateJavaScript` |
| `ApostrophePanels` (5 layouts, Adw.TimedAnimation) | `HSplitView`/`VSplitView` (or `NSSplitViewController`) + separate `NSWindow` |
| `pypandoc` / pandoc | Bundled `pandoc` binary via `Process`/`NSTask` |
| Typst PDF engine | Bundled `typst` binary; or `WKWebView.createPDF` fallback |
| `latex_to_PNG.py` (latex+dvipng) | SwiftMath/iosMath or KaTeX-in-WKWebView snapshot |
| `relative_to_absolute.lua`, templates, reference docs | Bundled in Resources, paths passed to pandoc |
| `GSettings` schema | `SettingsStore` over `UserDefaults` / `@AppStorage`; `@SceneStorage` for window state |
| `Adw.PreferencesDialog` | SwiftUI `Settings { TabView { … } }` scene |
| `Gtk.RecentManager` | `NSDocumentController.recentDocumentURLs` / Open Recent menu |
| `GtkSourceSearchContext/Settings` | `NSTextFinder` or custom search over `NSRegularExpression` |
| `GResource` (CSS/JS/fonts/templates) | Asset catalog + bundled Resources |
| GtkSourceView style schemes (light/dark/sepia XML) | Swift color palette structs per theme |
| GTK app CSS (style/dark/sepia/hc) | Native colors + appearance; high-contrast via accessibility flags |
| Web CSS (adwaita / sepia / hc) | Bundled CSS injected into `WKWebView` per theme |
| `pyenchant`/libspelling | `NSSpellChecker` (built into `NSTextView`) |
| `chardet` encoding detection | `String` encoding probing + fallback |
| Inhibitor (block logout while dirty) | `NSProcessInfo` activity / `NSDocument` dirty state |
| `.desktop` MimeType registration | `Info.plist` `CFBundleDocumentTypes` / `UTImportedTypeDeclarations` |
| gettext `po/` | String Catalogs (`.xcstrings`), seeded from po |
| `pride.py` | Swift `Date`→season enum + accent gradient |

---

## 4. Proposed Xcode Project Structure

**Targets**
- `Apostrophe` (main app, SwiftUI lifecycle, document-based).
- `ApostropheCore` (framework/SwiftPM local package): pure logic — highlighting, regex, stats, smart-edit, exporter, settings model. Unit-testable without UI.
- `ApostropheTests` / `ApostropheCoreTests`.
- Bundled tools (`pandoc`, `typst`, MathJax/KaTeX, reveal.js, Lua filter, templates, reference docs, fonts, CSS) under `Resources/`.

**Module / file breakdown**

```
Apostrophe/
  App/
    ApostropheApp.swift            // @main, DocumentGroup, Settings scene, Commands
    AppCommands.swift              // menu bar: File/Edit/Format/View/Help + shortcuts
    AppDelegate.swift              // open-file, reuse-empty-window, dedupe
  Document/
    MarkdownDocument.swift         // ReferenceFileDocument (UTType .md/.markdown/.txt)
    DocumentEncoding.swift         // detect-on-open, UTF-8-on-save
    SnapshotStore.swift           // autosave snapshots + crash/draft restore
  Editor/
    EditorView.swift               // SwiftUI host: column, accessory bars, autohide
    EditorTextView.swift           // NSViewRepresentable wrapper
    ApostropheTextView.swift       // NSTextView subclass: margins, font sizing,
                                   //   Hemingway intercepts, ⌘/⌃-click previews
    MarkdownTextStorage.swift      // NSTextContentStorage/NSTextStorage glue
    SmartEditController.swift      // auto-pair, list continue/renumber, tab indent
    FormatInserter.swift          // wrap/toggle bold/italic/heading/list/table…
    TypewriterScroller.swift      // centered/band scroll, cubic ease-out
    FocusModeController.swift     // sentence detection + dim rendering attrs
  Highlight/
    SyntaxHighlighter.swift        // debounced, per-paragraph attribute runs
    MarkdownPatterns.swift         // NSRegularExpression set (ported markup_regex)
    ThemePalette.swift            // colors/fonts/scale per theme
  Preview/
    PreviewController.swift        // convert→load→render state machine, coalescing
    PreviewWebView.swift          // WKWebView wrapper, context-menu trim, snapshot crossfade
    ScrollSyncBridge.swift        // WKUserScript + message handler
    PreviewSecurity.swift         // raw-HTML detection, ask/restricted/unrestricted
    PreviewLayout.swift           // full/half-width/half-height/windowed/closed
  Convert/
    PandocRunner.swift             // Process wrapper, arg builder, async/coalesce
    Exporter.swift                // quick + advanced export
    ExportFormats.swift           // formats.json model + option→arg mapping
    MathRenderer.swift            // SwiftMath/KaTeX-snapshot for inline math
  Stats/
    StatsEngine.swift              // markup strip + char/word/sentence/para/read-time
    StatsBar.swift                // bottom accessory + popover
  Find/
    FindController.swift           // NSTextFinder or custom regex find/replace
  Settings/
    SettingsStore.swift            // typed UserDefaults model (all gschema keys)
    SettingsView.swift            // SwiftUI Settings scene
  Theme/
    AppearanceController.swift     // light/dark/system/sepia + high-contrast
    PrideSeason.swift             // date→season accent
  Resources/
    pandoc, typst (binaries)
    css/{adwaita,adwaita-sepia,base,highcontrast}.css
    js/{scroll.js, mathjax|katex, reveal.js}
    lua/relative_to_absolute.lua
    templates/typst.typ, reference.docx, reference.odt
    formats.json, fonts/, Localizable.xcstrings
```

**Data flow**
1. `MarkdownDocument` holds the canonical text. Editing flows through `ApostropheTextView` → updates document text → marks dirty (`updateChangeCount`).
2. `textDidChange` → debounced `SyntaxHighlighter` rescans edited paragraph ranges and applies attribute runs; `StatsEngine` recomputes; `SnapshotStore` schedules a 5s autosave.
3. Selection change → `FocusModeController` recomputes sentence range + dim attrs; `TypewriterScroller` re-centers caret.
4. Document text + settings → `PreviewController` debounces a `PandocRunner` conversion (background), posts HTML to `PreviewWebView`; `ScrollSyncBridge` keeps scroll fractions in sync.
5. Export actions → `Exporter` builds args from `ExportFormats` + UI options → `PandocRunner` → file via `NSSavePanel`.
6. `SettingsStore` (`@AppStorage`) drives column width, theme, autohide, flavor, security, etc.; observed reactively by editor and preview.

---

## 5. Key Technical Decisions & Risks

**Markdown parsing for preview/export — bundle Pandoc.**
swift-markdown/cmark-gfm cannot reproduce Pandoc's footnotes, grid tables, definition lists, math, and especially the 19 export targets (DOCX/ODT/EPUB/slideshows/wiki/TeX). Decision: **bundle a static `pandoc` binary** (and `typst`) and shell out via `Process`. Risk: binary size (~tens of MB), universal (arm64+x86_64) builds, signing each embedded binary for notarization, and sandbox/`Process` interaction (App Store would require careful entitlements or dropping `Process` — favor Developer ID distribution initially).

**Live preview — WKWebView with offline assets.**
Inject theme CSS and bundle MathJax/KaTeX + reveal.js locally (rewrite script `src` to a custom scheme) so preview works offline and within WKWebView's sandbox. Use `loadFileURL(_:allowingReadAccessTo:)` or a `WKURLSchemeHandler` rather than universal file access. Crossfade via `takeSnapshot` to avoid reload flicker. Coalesce conversions (cancel previous `Task`).

**Syntax highlighting — TextKit 2 + NSRegularExpression.**
Drive highlighting ourselves (mirroring upstream's choice not to use a grammar engine). ICU regex supports `\p{L}`, lookbehind, named groups/backrefs, and atomic groups, so patterns port with `(?P<x>)→(?<x>)` and `(?P=x)→\k<x>`. Risks: performance on large documents (mitigate with per-paragraph rescans + debounce), correctness of the ported `URL`/`MATH` patterns (look malformed upstream — re-derive), and TextKit 2 maturity for hanging indents/full-line backgrounds (may need fragment decoration or a custom layout pass).

**Focus highlighting — non-destructive attributes.**
Apply dim color via `NSTextLayoutManager` rendering attributes (TextKit 2) or `NSLayoutManager` temporary attributes (TextKit 1) so the model/undo stays clean. Sentence bounds via `NLTokenizer(.sentence)` / `enumerateSubstrings(.bySentences)`. Risk: keeping dim in sync with edits + typewriter recentre without jank; honor Reduce Motion.

**Typewriter scrolling — custom animation.**
Compute caret line rect from the layout manager, animate `NSClipView.bounds.origin` with a cubic ease-out, distance-scaled duration, via `CVDisplayLink` or `NSAnimationContext`. Risk: fighting `NSTextView`'s own scroll-to-visible; disable/override default caret scrolling. This plus focus dimming are the two trickiest editor pieces.

**PDF/DOCX export strategy.**
- DOCX/ODT/EPUB/wiki/TeX: pandoc only.
- PDF: prefer **bundled Typst** (single static binary, matches upstream quick-export template). Fallback: `WKWebView.createPDF` (no external engine, but loses Typst layout). TeX-based PDF/Beamer/ConTeXt require a **detected system TeX** — gate those rows and steer users to Typst otherwise.

**Math rendering (inline preview).**
Avoid bundling TeX/dvipng. Use **SwiftMath/iosMath** (native LaTeX-math → `NSImage`) or render via KaTeX in an offscreen `WKWebView` and snapshot. Preview-pane math stays MathJax in-page.

**Smart editing & undo.**
Implement auto-pair, list continuation/renumber, and tab-indent in `NSTextViewDelegate`, each wrapped in a single `NSUndoManager` group. Risk: interaction with macOS autocorrect/smart quotes (disable smart substitutions in the editor to keep Markdown literal).

**Code-signing / distribution.**
Hardened runtime + Developer ID + notarization. Every embedded executable (`pandoc`, `typst`) must be signed and have the right entitlements; `Process` spawning is fine for Developer ID but problematic for App Store sandbox — plan App Store as a later, possibly pandoc-less, variant.

**Other risks:** preserving exact stats parity (CJK word counting, multilingual sentence terminators); encoding detection without `chardet`; replicating the autohide/reveal heuristics naturally on macOS; adapting GTK responsive header bars (macOS is less size-adaptive).

---

## 6. Phased Roadmap

**v0.1 — MVP (editable, highlighted, savable, previewable)**
- Document-based app: New/Open/Save/Save-As/Close, Open Recent, `.md/.markdown/.txt` associations, encoding detect + UTF-8 save, unsaved-changes guard.
- `NSTextView` editor: centered constrained column, dynamic font sizing, native undo/spellcheck, standard `⌘` shortcuts and menu bar.
- Live regex highlighting for the core set (headings, bold/italic/strike, code/inline code, links/images, lists, blockquote).
- Pandoc-backed live preview in `WKWebView` (full-width + half-width), bundled pandoc.
- Settings scene with core prefs; Light/Dark/System.

**v0.2 — Focus & flow**
- Focus mode (sentence dim) + vertical centering.
- Typewriter/centered smooth scrolling.
- Auto-hiding chrome; fullscreen.
- Stats bar (all 5 metrics, selectable, reading time).
- Find & Replace (regex + case toggles).
- Smart editing: auto-pair, list continue/renumber, tab indent.

**v0.3 — Authoring power**
- Full highlighting set (tables, rules, math, footnotes, frontmatter) + bold-italic, Setext headings.
- Format toolbar + Format menu (wrap/toggle, heading cycle, table inserter).
- Hemingway mode (+ first-run banner).
- Sepia theme + high-contrast; theme-matched preview CSS.
- Half-height + windowed preview layouts; scroll sync; preview security modes; Markdown-flavor selection.

**v0.4 — Export & extras**
- Quick export (PDF/Typst, HTML, ODT) + Copy HTML.
- Advanced export (full `formats.json` matrix, options form, TeX gating, reveal.js folder export, bundled templates/reference docs/Lua filter).
- Inline preview popovers (image/link/footnote/word/math); SwiftMath math rendering.
- Autosave snapshots + crash/draft restore banner.

**v1.0 — Parity & polish**
- Drag-and-drop (images/files), bundled tutorial document.
- Adaptive wide/compact toolbar; pride-season accent.
- Localization via String Catalogs (seed from po).
- Performance pass (large docs), accessibility audit (VoiceOver, Reduce Motion, Increase Contrast), notarized release pipeline.

---

## 7. Open Questions — Confirm Against the Local Fork

> **Historical planning note (pre-implementation).** This checklist was written before the rewrite, to be confirmed against the fork's source while building. The macOS app is now feature-complete; the section is kept only as a record of the original open questions. At the time it was written, everything above came from upstream `main`.

**Fork divergence**
- Does `CHANGES-fork.md` (currently empty) describe intentional deviations? Re-read the fork's `preferences_dialog.py` and `text_view.py` specifically — flagged as user-edited.
- Any features, defaults, modes, layout, or branding changed vs upstream?

**Highlighting / editor**
- Exact `markup_regex.py` patterns, character-for-character (escapes; the `URL` and `MATH` patterns look malformed upstream).
- Are HTML comments (`<!-- -->`) and display-math blocks (`$$…$$`) distinct highlight categories?
- Exact tag attribute values: per-heading scale factors, link/metadata/unfocused gray colors, blockquote margins (2,-2), code background source.
- Focus mode granularity (sentence vs paragraph) and whether it's user-configurable.
- Full set of auto-paired characters; exact placeholder strings (`Item`, `Header`, …); list indent unit (tab vs 2 spaces); ordered-list lettering behavior; `insert_table` cell-width formula (`min(…,20)`).
- Font-size bounds, characters-per-line, and which settings gate typewriter/focus/spellcheck.

**Preview / export**
- Full `AdvancedExportDialog.retrieve_args()` option→arg mapping (toc, number-sections, incremental, slide ratio, highlight-style option name).
- Contents of `pandoc_templates/typst.typ` and any other templates; exact `reference.docx`/`reference.odt` names/paths; whether the fork customizes them.
- Full text of `media/js/scroll.js` (observer/`setScrollScale`, message names).
- Is MathJax bundled or CDN-loaded by Pandoc (offline impact)?
- Complete `media/css/web/` file list and any code-highlight CSS.
- Contents of `data/reference_files` and `data/styles` directories.

**Settings / shortcuts / system**
- All gschema defaults (autosave-period 5, characters-per-line 66, color-scheme `system`, stat-default `words`, etc.) — any fork changes.
- Exact accelerators: confirm Find/Replace (Ctrl+F / Ctrl+H), shortcuts-overlay key, focus (Ctrl+D), Hemingway (Ctrl+T), preview (Ctrl+P), strikeout (Ctrl+Shift+D), headings (Ctrl+1..6), list item (Ctrl+U), separator (Ctrl+R) — and whether link/image/table/code/quote/checklist/ordered-list inserts have any default keys. (Several upstream Linux bindings collide with macOS standards — `⌘U`=underline, `⌘R`=reload, `⌘T`/`⌘P` reserved — and will be rebound per §2.2/the shortcuts table.)
- Drag-and-drop: accepted file/image types, copy-vs-link, target widget (check `Editor.ui`/text view code).
- Precise open-dialog extension filter (`.md`, `.markdown`, `.txt`, also `.mdown`/`.mkd`?).
- Spellcheck backend specifics and undo/redo behavior as present in the fork.
- Reading-time WPM (200) and stat label strings if customized.
- `pride.py` full season list, date ranges, CSS class names, and matching gradients.
