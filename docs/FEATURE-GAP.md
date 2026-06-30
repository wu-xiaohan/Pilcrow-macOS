# Feature Gap Analysis: GNOME Apostrophe vs. macOS Native Rewrite

> Generated from a parallel audit: 167 upstream features catalogued across editor,
> preview/export, app/chrome, and declarative UI, diffed against the macOS Swift sources.

## 1. Executive Summary

The macOS rewrite is a solid, well-architected port of Apostrophe's *core writing
experience* — the centered monospace column, the full 23-pattern live syntax highlighter
(a faithful port of `markup_regex.py`), focus mode with typewriter scrolling, smart
auto-pairing and list continuation, statistics, themes (incl. sepia), and a near-complete
pandoc export matrix (19 formats with the same option logic). For a writer who wants
distraction-free Markdown editing with a live preview and rich export, it is broadly
usable today.

The biggest gaps cluster in **formatting affordances** (no toolbar, no insert actions for
headers/lists/links/images/tables/blockquote/HR — only 4 inline toggles), **preview
sophistication** (no layout modes, no scroll-sync, no security model, no inline "Peek"
popover, no per-theme highlight tuning), **session/file robustness** (no autosave/crash
recovery, no recents popover, no external-change detection, no encoding auto-detect beyond
UTF-8/Latin-1), and **chrome/UX** (no Hemingway toast or keybinding, no fullscreen/
distraction-free auto-hide, no shortcuts overlay, no preferences for ~7 declared settings).
Several settings keys exist in the store but are entirely unwired (`sync-scroll`,
`input-format`, `autohide-headerbar`, `toolbar-active`, `autosave-period`, `preview-mode`,
`preview-security`). It also drops the dictionary/LaTeX/footnote Peek previews,
drag-and-drop image insertion, the pride easter egg, and the table size-picker. Overall:
roughly **55–65% feature parity**, strongest on the editor engine, weakest on preview
variants, formatting UI, and session management.

---

## 2. Gap Tables by Category

### Editor & Highlighting
| Feature | Status | Notes |
|---|---|---|
| Italic/Bold/Bold-italic/Strikethrough/Code/Math highlight | ✅ | full ported pattern set |
| Links / Images / Autolinks `<url>` | ✅ | dims markup, colors text |
| Fenced code block; Setext header | ✅ | |
| Responsive font ramp + column width; Bigger text | ✅ | full ramp + min-width |
| Color scheme drives highlight palette | ✅ | |
| Horizontal-rule centering | 🟡 | no CENTER justification |
| Blockquote indent | 🟡 | colored + italic, no hanging margin |
| ATX headers | 🟡 | scaled/bold/dimmed hashes; no negative-margin hang |
| Table no-wrap | 🟡 | mono font; wide tables still wrap |
| Background parse | 🟡 | whole-storage main thread, 30ms debounce |
| Tab width (4 chars) | ❌ | not configured |

### Smart Editing
| Feature | Status | Notes |
|---|---|---|
| Bold/Italic/Strikethrough/Inline-code toggle | ✅ | trim + toggle-off + placeholder |
| Unordered + checklist continuation | ✅ | empty item terminates |
| Auto-pair / skip-over | 🟡 | `( [ { \``; **missing `"` and `<`/`>`** |
| Ordered list continuation | 🟡 | numeric only; lettered → `1.` |
| Tab / Shift+Tab list indent + cycle/renumber | ❌ | default insert |

### Format Insertion (biggest gap)
| Feature | Status | Notes |
|---|---|---|
| Code block / Horizontal rule insert | ❌ | only inline-code toggle |
| Header insert + level cycling | ❌ | |
| List / checklist / ordered insert+toggle | ❌ | |
| Blockquote insert / toggle | ❌ | |
| Link / Image insert | ❌ | |
| Table insert via size picker | ❌ | |
| Live table reformatting | ❌ | legacy upstream anyway |
| Formatting toolbar (wide + narrow) | ❌ | only Export/Focus/Preview buttons |
| Drag-and-drop file/image insert | ❌ | |

### Preview
| Feature | Status | Notes |
|---|---|---|
| Live render (pandoc→HTML); MathJax | ✅ | off-main, 150ms debounce |
| Per-theme CSS; anti-flash | 🟡 | single generated CSS |
| Dark-theme code highlighting | ❌ | no `breezedark` |
| Layout modes (full/half-w/half-h/windowed) + switcher | ❌ | only right split; `preview-mode` unused |
| Scroll synchronization | ❌ | `sync-scroll` unused |
| Security modes (ask/restricted/unrestricted) | ❌ | `preview-security` unused |
| Inline "Peek" popover (image/math/link/footnote/dictionary) | ❌ | none; no Cmd-click |

### Export
| Feature | Status | Notes |
|---|---|---|
| 19 formats; TOC; numbers; page/slide size; self-contained; syntax style; incremental; Typst PDF; Copy HTML | ✅ | full option parity |
| Absolute-paths lua filter | 🟡 | bundled; wiring unconfirmed |
| reveal.js folder export | ❌ | single file; no reveal.js copy |
| Bundled pandoc/typst | ❌ | relies on Homebrew |

### Modes / Focus / Typewriter
| Feature | Status | Notes |
|---|---|---|
| Focus dimming + vertical centering | ✅ | NLTokenizer + temp attrs |
| Focus disables spellcheck | ❌ | not coupled |
| Smooth ease-out centering | 🟡 | native scroll |
| Hemingway (block deletes) | 🟡 | **Settings-only toggle**, no menu/keybinding |
| Hemingway shake + toast + help | ❌ | beep only |

### Stats / Find / Themes
| Feature | Status | Notes |
|---|---|---|
| Selectable stat bar; 5 metrics; read time | ✅ | persisted |
| "X of Y" selection-aware count; narrow variant | ❌ | |
| Find/Replace/Next/Prev/Replace-All | ✅ | NSTextFinder |
| Explicit regex/case toggles | 🟡 | NSTextFinder defaults |
| System/Light/Dark/Sepia | ✅ | |
| High-contrast schemes | ❌ | |

### Settings / Files / Window
| Feature | Status | Notes |
|---|---|---|
| Prefs window (Appearance+Editor); spellcheck/bigger/hemingway/chars-per-line | ✅ | provisional |
| auto-hide / input-format / preview-security / restore-session prefs | ❌ | declared, no UI/behavior |
| Open/Save/Save As/UTF-8 | ✅ | DocumentGroup |
| Encoding detection on load | 🟡 | UTF-8→Latin-1 only |
| Autosave / crash snapshots / restore | ❌ | `autosave-period` unused |
| Recent-files popover (search/prune) | ❌ | system Open Recent only |
| External file-change detection / reload | ❌ | no monitor |
| Fullscreen chrome-hide / distraction-free auto-hide | ❌ | `autohide-headerbar` unused |
| Keyboard Shortcuts overlay | ❌ | |
| Fuller main menu (modes/theme/prefs/tutorial/about) | ❌ | only Format + Find + Help |
| Open Tutorial doc; About w/ debug; detailed-error dialog | ❌/🟡 | export errors only |
| Logout/shutdown inhibition (unsaved) | ❌ | |

### System / Localization / Easter eggs
| Feature | Status | Notes |
|---|---|---|
| File-type/MIME association; open from Finder; app icon | ✅ | |
| 50-language localization | ❌ | English only |
| Pride/identity-awareness seasonal CSS | ❌ | |

---

## 3. Missing Keyboard Shortcuts
| Upstream | Action | Suggested Mac |
|---|---|---|
| Ctrl+T | Toggle Hemingway | ⌃⌘H |
| F11 | Fullscreen | native ⌃⌘F |
| F7 | Toggle spellcheck | ⇧⌘; |
| Ctrl+R | Horizontal rule | ⌃⌘R |
| Ctrl+1..4 | Header level 1–4 | ⌘1..⌘4 |
| Ctrl+U | List item | ⇧⌘U |
| Ctrl+? | Shortcuts overlay | ⌘/ |
| — | Insert link / image | ⌘K / ⇧⌘K |
| — | Insert blockquote / code block | ⌃⌘B / ⌥⌘C |

---

## 4. Prioritized "What to Build Next"

**P0 — core parity**
- Formatting insert actions + toolbar (headers, lists, blockquote, link, image, code block, HR, table picker).
- Tab / Shift+Tab list indent + bullet cycling / renumbering.
- Autosave & crash recovery (snapshots + restore banner).
- External file-change detection (monitor + reload banner).
- Robust encoding detection + error dialog.
- Wire Hemingway toggle to a menu/keyboard command.

**P1 — important**
- Preview layout modes + switcher; scroll sync; security model; dark highlight style.
- Recent-files popover (search/prune).
- Inline "Peek" popover (image + link + math first).
- Input-format wired into pandoc; shortcuts overlay + fuller menus; auto-hide chrome.
- reveal.js folder export; finish auto-pairing (`"`,`<`); focus-mode disables spellcheck.

**P2 — nice-to-have**
- Header hang / blockquote / HR / table layout fidelity; drag-and-drop insertion.
- "X of Y" stats; About-with-debug; detailed-error dialog; logout inhibition.
- Bundle pandoc/typst in Resources/Tools; tutorial doc; localization; pride egg; high-contrast.

---

## 5. macOS-only or Improved
- Native **NSTextFinder** find bar; **NLTokenizer** sentence detection.
- **Layout-manager temporary attributes** for focus dimming (keeps highlighter attrs intact).
- **SwiftUI DocumentGroup** (native Open Recent, OS versions/autosave, window restoration).
- `focus-mode` persisted; unified Export sheet; WKWebView anti-flash; unit-tested pure core.
