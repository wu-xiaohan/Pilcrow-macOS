Source is fully populated and readable; I verified spec claims against it. Findings below.

---

**P0 — Foundational / will block or force rework**

1. **§7 premise is false.** The fork source is NOT 0-byte stubs — every file is populated (e.g. `main_window.py` 35KB, `text_view_format_inserter.py` 23KB, `markup_regex.py` 8KB) and readable now. Every "confirm later" open question in §7 is answerable today and several spec claims are already contradicted (items 2–6). Resolve §7 before freezing architecture.

2. **Document model is self-contradictory.** Prose says `NSDocument`/`DocumentGroup` and claims "free … autosave-in-place, Versions/Time-Machine restore"; the file layout declares `MarkdownDocument.swift // ReferenceFileDocument`. SwiftUI `ReferenceFileDocument` does NOT give you autosave-in-place, Versions, or async saving for free — those require `NSDocument` (or significant opt-in). Pick one; the "free Versions/Time-Machine" claim is overstated for the SwiftUI path.

3. **Custom `SnapshotStore` (5s) conflicts with NSDocument autosave/Versions.** You cannot run both autosave-in-place + Versions AND a parallel 5s snapshot/restore without double-writes and confused dirty state. Upstream's `autosave-period=5` should map to `NSDocument.autosavingDelay`, not a bespoke store. The two §2.10 rows ("Autosave snapshots" + "autosave-in-place or custom") are mutually exclusive — decide.

4. **TextKit 2 chosen as primary is the largest unhedged risk.** Focus-dim, full-line backgrounds (code blocks, blockquote left bar), and hanging-indent heading markers — exactly the upstream behaviors — are where TextKit 2 is weakest, and TK2 has no stable equivalent of TK1's `setTemporaryAttributes:`. Spec acknowledges in prose but still picks TK2 in §1/§4 with no spike gating it. This must be a pre-v0.1 spike; many shipping editors fall back to TextKit 1.

5. **Per-paragraph rescan is incompatible with the actual regexes.** Verified: `CODE_BLOCK` (DOTALL/MULTILINE), `FRONTMATTER` (whole-doc head), `TABLE` (grid, multi-line), `FOOTNOTE` (multi-line), `HEADER_UNDER` (setext, needs next line), `HORIZONTAL_RULE` (needs `\n{2,}` context). The §2.2/§4 "debounced per-paragraph rescan" will mis-highlight all of these. You need block-aware/widened rescan windows, not paragraph-local.

6. **MathJax is CDN-loaded, not bundled.** `preview_converter.py` uses pandoc `--mathjax`, which injects a remote cloudflare `<script src>`. Nothing offline exists in the fork. So §2.3 "bundle MathJax/KaTeX offline" is net-new work requiring HTML post-processing to rewrite the injected `src` to a custom scheme. Worse: `scroll.js` readiness logic uses the **MathJax v2** `MathJax.Hub` API (`queue.running/pending`) to decide `isRendered` for scroll-sync; swapping to MathJax v3 or KaTeX silently breaks scroll-sync gating.

**P1 — Concrete parity gaps / wrong mappings**

7. **Font ramp wrong.** Verified `_get_font_sizes()` = `[20,18,17,16,15,14]` (default 16), not the spec's "~14–24pt." Fix the size ramp and default.

8. **Pipe tables aren't highlighted.** The `TABLE` regex only matches grid tables (`+---+`/`-----`). The table inserter emits GFM **pipe** tables, so inserted tables won't be styled. §2.2 "Tables" is misleadingly generic. Decide whether to add a pipe-table pattern (upstream lacks one).

9. **`fix_table.py` (6.7KB) is entirely absent from the parity checklist.** Upstream has live table reformatting/alignment-on-edit. Not mapped anywhere in §2/§3.

10. **`inline_preview.py` (17KB) is reduced to one checklist line.** It's one of the largest modules (image/math/link/footnote/word popovers + `latex_to_PNG`). Under-scoped for a "should-have."

11. **"Pride season" is mischaracterized.** `pride.py` defines 13 identity-awareness periods (intersex, lesbian, aids, autism, pan, trans, aro, ace, bi, non-binary, pride, disability, black-history) with nth-weekday date math (e.g. computing weeks off Feb 14 / last-Sunday-of-October). Spec's "Date→season accent gradient, no setting" trivializes nontrivial date logic and the full identity list + per-class gradients.

12. **HTML export name pin.** `export_dialog.py` uses `--embed-resources --standalone` (pandoc ≥2.19), not `--self-contained` (the spec's wording). The bundled pandoc version must be pinned to match all flags used (and upstream behavior); spec never pins a pandoc version.

13. **Encoding detection has no chosen mechanism.** Spec drops `chardet` for "String encoding probing," but Swift has no equivalent; `String(contentsOf:usedEncoding:)` only reports the encoding it happened to decode with and won't detect legacy/CJK encodings. §2.10 "encoding detection on open" (priority M, in v0.1) is a blocker with no library named.

14. **No native Print.** Spec rebinds ⌘P away from preview but never assigns `File > Print` (`NSPrintOperation`). macOS users expect Print; also a no-TeX PDF path.

15. **The referenced "shortcuts table" does not exist.** §7 and §2.2 repeatedly say collisions "will be rebound per the shortcuts table," but no such table is in the document. Every ⌘U/⌘R/⌘T/⌘P/⌘1–6 collision is flagged but none is actually resolved.

**P1 — macOS conventions ignored**

16. **No Quick Look extension.** A native Markdown editor should ship a QL Thumbnail + Preview extension for `.md`. Unmentioned.

17. **Services provider not implemented.** §1 lists "system services" but there's no Services menu *provider* (e.g. "New Apostrophe Document from Selection" / export selection). Only consuming services is implied.

18. **No Handoff/Continuity (`NSUserActivity`)** and **no iCloud Drive ubiquity-container config/entitlement** despite §1 invoking Continuity-class nativeness. DocumentGroup gives iCloud UI but you still must declare the container + entitlements.

19. **No Spotlight metadata importer** for indexing `.md` content/frontmatter.

20. **Sandbox ↔ Process(pandoc) ↔ relative images underspecified.** `relative_to_absolute.lua` + `base_path` rewrite image paths relative to the document folder; under App Sandbox, pandoc (spawned, inheriting sandbox) needs security-scoped access to that folder, and export destinations need powerbox/security-scoped bookmarks. Spec waves at "Developer ID first," but even Developer ID + hardened runtime needs the embedded binary signed and the temp/working-dir I/O planned. This will bite at first real preview of a doc with local images.

**P2 — Roadmap sequencing**

21. **Embedded-binary signing/notarization deferred to v1.0 but required by v0.1.** v0.1 ships bundled pandoc in `WKWebView` preview; you cannot even test-distribute v0.1 without solving hardened-runtime signing of `pandoc`. Move the codesign/notarize-embedded-binary pipeline to v0.1.

22. **MathJax-offline decision deferred but needed in v0.1.** Preview (v0.1) emits `--mathjax`; scroll-sync (v0.3) depends on its readiness API. The bundle-vs-CDN + MathJax-version decision must land in v0.1, not be left open.

23. **Focus mode (v0.2) precedes the full highlighting set (v0.3).** Focus dim and syntax runs share the same attribute layer; building dim before the highlighter's attribute-layering model is finalized invites rework. Settle the attribute/rendering-attribute layering (and the TK1/TK2 spike, item 4) before either.

24. **Encoding library (item 13) is a v0.1 blocker** with no owner in the roadmap.

**P2 — Implementation bites**

25. **Verify ordered-list renumber actually renumbers.** Code path uses `next_prefix` via `idle_add` after insert; spec asserts "ordered renumber" — confirm it renumbers the whole list vs. only increments the next marker (and letter-list `[a-z]+` behavior).

26. **ICU regex porting caveats beyond the named-group swap.** `ORDERED_LIST` uses an atomic group `(?>…)`; `BOLD_ITALIC` relies on numbered backrefs `\5\4|\3\2` whose indices must be re-counted after VERBOSE stripping; confirm ICU possessive/atomic + `re.VERBOSE` comment stripping all map. (ICU supports these, but silent group-number drift will corrupt BOLD_ITALIC.)

27. **URL regex is genuinely broken, not just "looks malformed."** `[(http(s)?):\/\/(www\.)?a-zA-Z0-9...]{2,256}` is a character class containing literal `(`, `h`, `t`, `p`, `s`, `?`, `)` — it does not match what it intends. Must be re-derived from scratch, not ported.

28. **Disable more than smart quotes in the editor.** Beyond `automaticQuoteSubstitution`, you must disable `automaticTextReplacement`, `automaticDashSubstitution`, `automaticSpellingCorrection`, and data detectors to keep Markdown literal — and reconcile with `NSTextView`'s own `scrollRangeToVisible` fighting the typewriter scroller. Spec mentions only smart quotes.

29. **`detailed_error.py` / `TexliveWarning.ui` / `inhibitor.py` (logout block while dirty)** have no concrete macOS counterpart in §4 (inhibitor→`NSProcessInfo` is named but sudden-termination / `disableSuddenTermination` interplay with autosave is not addressed).

30. **Concrete gschema defaults the spec leaves "to confirm" are present now:** `color-scheme=system`, `spellcheck=true`, `sync-scroll=true`, `input-format=markdown`, `autohide-headerbar=true`, `stat-default=words`, `characters-per-line=66` (range 40–160, the fork's one real divergence per `CHANGES-fork.md`), `preview-mode=full-width`, `preview-security=ask`, `preview-active=false`, `toolbar-active=false`, `bigger-text=false`, `autosave-period=5`. Bake these in rather than re-deriving.
