# Using Pilcrow

Pilcrow is a distraction-free Markdown editor: a clean, centered writing column with
everything else tucked into a slim toolbar that stays out of your way. This guide
explains the window, what every icon does, and the keyboard shortcuts.

New to Markdown itself? Read [`tutorial.md`](tutorial.md) first.

---

## The window at a glance

```
┌─────────────────────────────────────────────────────────────┐
│  (title)                    ⬆  ⏱  🎹 🍃 ♫   ▥  •••           │  ← top toolbar
├─────────────────────────────────────────────────────────────┤
│                                                               │
│                  your centered writing column                 │
│                                                               │
├─────────────────────────────────────────────────────────────┤
│  ›                                   words · chars · read time │  ← bottom bar
└─────────────────────────────────────────────────────────────┘
```

- **Writing column** — centered and width-limited for comfortable reading. You set the
  width with *Characters per line* (Preferences).
- **Top toolbar** — export, Pomodoro, sounds, preview, and the main menu (right side).
- **Bottom bar** — a collapsible formatting toolbar on the left, live document stats on
  the right.
- In **fullscreen** the toolbar auto-hides; move the pointer to the top to reveal it.

---

## Top toolbar icons (left → right)

| Icon | Meaning | What it does |
| --- | --- | --- |
| **⬆ share box** (`Export`) | Export | Opens the export sheet — save as PDF, HTML, Word, and ~19 other formats, or copy HTML. Shortcut **⇧⌘E**. |
| **⏱ timer** (becomes a **☕ cup** on breaks) | Pomodoro | Click to open the focus/break timer popover. Shows a live countdown when running. |
| **🎹 piano keys** | Background sound: Piano | Calm instrumental tracks. |
| **🍃 leaf** | Background sound: Nature | Rain, fire, forest, etc. |
| **♫ music note** | Background sound: Your music | Plays songs you add yourself. |
| **▥ sidebar** (`Preview`) | Live preview | Click to toggle the rendered preview (**⇧⌘P**). Open its menu for the layout. |
| **••• circle** | Main menu | Themes, writing modes, and Preferences (see below). |

### The three sound icons (🎹 🍃 ♫)

Each behaves the same way:

- **Click** — start/stop that sound source (the active one is highlighted).
- **Double-click** — skip to the next track in that playlist.
- **Triple-click** — pop up a **volume** slider.

The sound pauses automatically with the Pomodoro timer, and calm music takes over during
breaks. Add your own songs in **Preferences → Background Sounds → Add Music…**.

### The main menu (•••)

- **Your two favourite themes** (shown with a colour swatch) for one-click switching.
- **Color Theme ▸** — the full palette list.
- **Pick Your Color…** — choose a custom background colour.
- **Focus Mode**, **Hemingway Mode**, **Bionic Reading** — toggle the writing modes.
- **Preferences…** — all settings (**⌘,**).

---

## Bottom formatting bar (›)

At the bottom-left is a single **chevron ›**. Click it to unfold a row of formatting
buttons; it becomes **‹** to fold them away again. Each button applies to your selection
(or inserts a placeholder):

| Icon | Action | Shortcut |
| --- | --- | --- |
| **B** | Bold | ⌘B |
| **I** | Italic | ⌘I |
| **S̶** | Strikethrough | ⇧⌘X |
| **#** | Heading | ⌘1 |
| **• list** | Bullet list | ⇧⌘U |
| **1. list** | Numbered list | ⇧⌘O |
| **☑ checklist** | Checklist | ⇧⌘L |
| **❝ quote** | Blockquote | ⇧⌘B |
| **{ } braces** | Code block | ⌥⌘C |
| **🔗 link** | Insert link | ⌘K |

On the bottom-**right**, the stats bar shows your word count, character count, and
estimated reading time, updating as you type.

---

## Writing modes

| Mode | What it does | Where |
| --- | --- | --- |
| **Focus Mode** | Dims everything except the sentence you're writing, and keeps it centered (typewriter scrolling). | ••• menu or **⇧⌘D** |
| **Hemingway Mode** | Disables deleting — you can only move forward. Good for fast first drafts. | ••• menu or **⌃⌘H** |
| **Bionic Reading** | Bolds the first part of each word to help your eyes scan. | ••• menu |
| **Fullscreen** | Hides the toolbar for a blank-page feel (hover the top edge to show it). | green window button / ⌃⌘F |

---

## Themes and fonts

- **Themes:** System, White, Dark, **Sepia (default)**, plus six soft palettes —
  Lavender Mist, Periwinkle, Soft Sky, Soft Apricot, Warm Sand, and Sage. Pick from the
  ••• menu, or use **Pick Your Color…** for a custom background. Pin two as favourites for
  one-click access.
- **Fonts:** in Preferences you can choose a **Latin font** and, independently, a **CJK
  font** (for Chinese/Japanese/Korean). Both the editor and the preview render each script
  in its chosen font automatically.

---

## Preview and export

- **Preview** (▥ / ⇧⌘P) renders your Markdown live. Open the preview button's menu to pick
  a layout: **Half Width** (side by side), **Full Width** (preview only), or **Half
  Height** (stacked).
- **Export** (⬆ / ⇧⌘E) converts your document — PDF (via Typst), HTML, Word (`.docx`),
  ODT, LaTeX, reStructuredText, EPUB, and more — or **Copy HTML** to the clipboard.
  Everything is built in; nothing extra to install.

---

## Pomodoro timer (⏱)

Click the timer to open its popover:

- **Start / Pause**, **Skip** (jump to the next phase), **Reset**.
- Set **Focus** length (1–180 min) and **Break** length (1–60 min).
- It counts your **completed sessions**, and the toolbar icon switches to a **☕ cup**
  during breaks (when calm break music plays).

---

## Find & replace

| Action | Shortcut |
| --- | --- |
| Find… | ⌘F |
| Find and Replace… | ⌥⌘F |
| Find Next | ⌘G |
| Find Previous | ⇧⌘G |

---

## Preferences (⌘,)

- **Appearance** — colour scheme, *Bigger text*.
- **Editor** — check spelling while typing, Hemingway mode, Bionic reading, and
  **Characters per line** (40–160): the width of your writing column. Type a number or use
  the stepper — it applies live.
- **Fonts** — Latin and CJK fonts.
- **Background Sounds** — volume, plus add/remove your own music.

---

## Your work is safe

- **Auto-recovery** — Pilcrow snapshots unsaved changes; if it ever quits unexpectedly,
  it offers to restore them next time.
- **External-change detection** — if another app changes the open file, Pilcrow shows a
  banner offering to reload (it won't overwrite your unsaved edits silently).
- **Smart encoding** — it detects a file's text encoding when opening, so non-UTF-8
  documents open correctly.

---

## Keyboard shortcuts — full list

**Formatting**

| ⌘B Bold | ⌘I Italic | ⇧⌘X Strikethrough | ⇧⌘C Inline code |
| --- | --- | --- | --- |
| ⌘K Link | ⇧⌘K Image | ⌘1–⌘6 Headings 1–6 | ⌥⌘C Code block |
| ⇧⌘U Bullet list | ⇧⌘O Numbered list | ⇧⌘L Checklist | ⇧⌘B Blockquote |
| ⌃⌘R Horizontal rule | | | |

**View & tools**

| ⇧⌘P Toggle preview | ⇧⌘D Focus mode | ⌃⌘H Hemingway mode | ⇧⌘E Export |
| --- | --- | --- | --- |
| ⌘F Find | ⌥⌘F Find & replace | ⌘G Find next | ⇧⌘G Find previous |
| ⌘, Preferences | ⌘S Save | ⌘O Open | ⌘N New |

Happy writing.
