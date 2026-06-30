# Writing Markdown — a quick tutorial

Markdown is a way to write **formatted text using plain characters**. You type simple
marks like `#` or `*`, and Pilcrow shows the styling live and renders a clean document
in the preview (and in every export). You never need to leave the keyboard.

This tutorial covers everything you can write. In Pilcrow you can type these marks by
hand, or let the app insert them for you (see the shortcuts in the right column and
[`instruction.md`](instruction.md)).

> Tip: select some text first, then apply a mark — Pilcrow wraps the selection.

---

## Headings

Start a line with `#`. More hashes = smaller heading (levels 1–6).

```markdown
# Title (H1)
## Section (H2)
### Subsection (H3)
```

| You type | You get | Shortcut |
| --- | --- | --- |
| `# Big`     | largest heading | ⌘1 |
| `###### Small` | smallest heading | ⌘6 |

---

## Emphasis

```markdown
*italic*  or  _italic_
**bold**  or  __bold__
***bold italic***
~~strikethrough~~
`inline code`
```

| Mark | Result | Shortcut |
| --- | --- | --- |
| `*text*` | *italic* | ⌘I |
| `**text**` | **bold** | ⌘B |
| `~~text~~` | ~~strikethrough~~ | ⇧⌘X |
| `` `text` `` | `inline code` | ⇧⌘C |

---

## Lists

**Bullets** — start lines with `-`, `*`, or `+`:

```markdown
- Milk
- Eggs
  - (indent two spaces for a sub-item)
```

**Numbered** — start lines with `1.`, `2.`, …:

```markdown
1. First
2. Second
3. Third
```

**Checklist / to-do** — bullets with `[ ]` (empty) or `[x]` (done):

```markdown
- [ ] Draft the chapter
- [x] Make coffee
```

| List type | Shortcut |
| --- | --- |
| Bullet list | ⇧⌘U |
| Numbered list | ⇧⌘O |
| Checklist | ⇧⌘L |

> In Pilcrow, pressing **Return** in a list continues it automatically, and **Tab** /
> **Shift-Tab** indents or outdents the current item.

---

## Links and images

```markdown
[visible text](https://example.com)
![alt text](path/to/image.png)
```

- A **link** is square brackets (the text) followed by parentheses (the URL): ⌘K.
- An **image** is the same with a leading `!`: ⇧⌘K. The path can be a file on your Mac
  or a web URL; images appear in the preview and exports.

---

## Blockquotes

Start a line with `>`:

```markdown
> This is a quote.
> It can span multiple lines.
```

Shortcut: ⇧⌘B. Nest deeper with `>>`.

---

## Code

**Inline** — wrap in single backticks: `` `let x = 1` `` → `let x = 1`.

**Code block** — fence with three backticks, optionally naming the language for
syntax highlighting (⌥⌘C inserts a block):

````markdown
```swift
func greet() {
    print("Hello")
}
```
````

---

## Horizontal rule

Three or more dashes on their own line draw a divider (⌃⌘R):

```markdown
---
```

---

## Tables

Columns are separated by `|`; the second row sets alignment (`:---` left, `:---:`
center, `---:` right):

```markdown
| Item    | Qty | Price |
| :------ | :-: | ----: |
| Coffee  |  2  | 3.50  |
| Tea     |  1  | 2.00  |
```

---

## Footnotes

Reference a note with `[^id]`, then define it anywhere:

```markdown
Here is a claim.[^1]

[^1]: And here is the supporting note.
```

---

## Paragraphs and line breaks

- A **blank line** separates paragraphs.
- To force a line break *within* a paragraph, end a line with **two spaces** (or a
  backslash `\`).

---

## A few extras

Pilcrow renders Markdown with **pandoc**, so these also work:

```markdown
Superscript: x^2^      Subscript: H~2~O
Definition list:
Term
:   Its definition
```

---

## Putting it together

```markdown
# My Notes

Some **important** background, with a [reference](https://example.com).

## To do
- [x] Outline
- [ ] First draft

> "Write drunk, edit sober." — attributed to many

```swift
print("ready")
```
```

That's the whole language. For everything about the app itself — the icons, modes,
themes, export, and shortcuts — see [`instruction.md`](instruction.md).
