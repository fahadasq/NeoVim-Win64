# Neovim Configuration Reference

Quick-reference for all keybindings, features, and conventions in this Neovim
setup.  The config runs inside **Neovide** (a GPU-accelerated GUI for Neovim)
launched via `nvim.bat`.

---

## 1. Startup & Layout

When Neovim opens it creates:

- **Two vertical editor panes** (left + right) — for side-by-side editing.
- **A terminal panel** pinned to the bottom-left — a persistent shell (cmd.exe
  by default) that stays open for the entire session.

The terminal panel starts at 6 lines tall and can be expanded.

---

## 2. Navigation & Movement

### Cursor movement (Normal and Visual mode)

| Key | Action |
|-----|--------|
| `Ctrl+L` | Move right to next **camelCase / symbol boundary** |
| `Ctrl+H` | Move left to previous **camelCase / symbol boundary** |
| `Shift+L` | Move right to next **treesitter token** (falls back to camel) |
| `Shift+H` | Move left to previous **treesitter token** (falls back to camel) |
| `Ctrl+Shift+L` | Jump to **end of line** (`$`) |
| `Ctrl+Shift+H` | Jump to **first non-blank** (`^`) |

**Camel-case boundaries** split on: uppercase after lowercase (`camelCase` →
`camel|Case`), digits touching letters (`foo42bar` → `foo|42|bar`), and
punctuation/symbols.

**Underscores:** when moving with `Ctrl+L` / `Ctrl+H`, an `_` directly followed
by a letter or digit is treated as a single stop — moving right lands on the
`_`, moving left lands on the character after it (so `snake_case` doesn't take
two presses to cross the `_c`).  Deletion (`Ctrl+D` / `Ctrl+Backspace`) is not
affected and still stops at both.

**Treesitter tokens** use the syntax tree to jump between leaf nodes (keywords,
identifiers, operators, literals).  If no treesitter parser is available, it
falls back to camel-case movement.

### Reference jumping (Normal mode)

| Key | Action |
|-----|--------|
| `Shift+J` | Jump to the **next occurrence** of the word under the cursor |
| `Shift+K` | Jump to the **previous occurrence** of the word under the cursor |

Occurrences come from `vim-illuminate` (LSP references, then treesitter, then
plain text matching), which also highlights them while the cursor rests on a
word.  Both keys stop at the last / first occurrence instead of wrapping
around.

### Jump list (Normal mode)

| Key | Action |
|-----|--------|
| `Alt+J` | Jump **back** in the jump list (replaces `Ctrl+O`) |
| `Ctrl+J` | Jump **forward** in the jump list (replaces `Ctrl+I`, which opens the buffer picker) |

### Scrolling

| Key | Action |
|-----|--------|
| `Ctrl+F` | Scroll **down 20 lines** and center |
| `Ctrl+B` | Scroll **up 20 lines** and center |
| `z` | **Center** current line on screen (`zz`) |

---

## 3. Editing

### Deletion (Normal mode)

| Key | Action |
|-----|--------|
| `Ctrl+D` | Delete forward to next **camel boundary** |
| `Ctrl+Backspace` | Delete backward to previous **camel boundary** |
| `Shift+D` | Delete forward to next **treesitter token** |
| `Shift+Backspace` | Delete backward to previous **treesitter token** |
| `Ctrl+Shift+D` | Delete to **end of line** (`D`) |
| `Ctrl+Shift+Backspace` | Delete to **start of line** (`d^`) |
| `Alt+D` | Delete the **entire current treesitter token** under cursor |
| `Backspace` | Delete character to the left (`X`) |
| `Space` | Insert a space at the cursor (stays in Normal mode) |

### Deletion (Insert mode)

| Key | Action |
|-----|--------|
| `Ctrl+Backspace` | Delete backward to previous **camel boundary** |
| `Shift+Backspace` | Delete backward to previous **treesitter token** |

### Comment toggling

| Key | Mode | Action |
|-----|------|--------|
| `Ctrl+/` | Normal | Toggle comment on current line |
| `Ctrl+/` | Visual | Toggle comment on selected lines |

### Re-indent

| Key | Mode | Action |
|-----|------|--------|
| `Ctrl+Y` | Visual | Re-indent selection (`=`) |

### Standard shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+S` | **Save** file (creates missing directories with confirmation) — Normal, Insert, Visual.  In a Claude diff it **accepts** the proposal |
| `Ctrl+C` | **Copy** selection to system clipboard (Visual mode) |
| `Ctrl+V` | **Paste** from system clipboard (Insert mode) |
| `Alt+W` | Toggle **word wrap** on/off |

---

## 4. File Operations

| Key | Action |
|-----|--------|
| `<leader>fr` | **Rename** current file (prompts for new path) |
| `<leader>fd` | **Delete** current file (with confirmation) |

The `<leader>` key is `\` by default (Neovim default; not remapped here).

---

## 5. Escape & Float Dismissal

| Key | Mode | Action |
|-----|------|--------|
| `Esc` / `Ctrl+G` / `Ctrl+[` | Normal | Dismiss floating windows (diagnostics, hover) and clear search highlighting |
| `Ctrl+G` / `Ctrl+[` | Insert, Visual | Return to Normal mode and clear search highlighting |
| `Ctrl+G` / `Ctrl+[` | Command | Cancel the command line (same as `Esc`) |

Inside a Claude diff proposal, the Normal-mode `Esc` / `Ctrl+G` / `Ctrl+[`
**reject** the proposal instead (an open popup is dismissed first, as above).
See [Diffs](#claude-code-panel) under the Claude Code panel.

---

## 6. Window & Panel Management

### Splitting

| Key | Action |
|-----|--------|
| `Ctrl+\` | **Vertical split** (from an editor window) |
| `Alt+\` | **Horizontal split** — from terminal: creates editor above it and resets terminal height; from editor: standard horizontal split |

### Closing / resetting

| Key | Action |
|-----|--------|
| `Ctrl+K` | **Kill buffer** — closes the current buffer (does nothing in the terminal or Claude panels; in a Claude diff it **rejects** the proposal) |
| `Ctrl+Shift+K` | **Close window** — with confirmation.  Won't close the terminal; in the Claude panel it **hides** the panel (no confirmation); in an editor lent to a Claude diff it **rejects** the proposal and keeps the window |
| `Alt+0` | **Single window layout** — keeps only the current window (or the last editor, if on the terminal); the terminal is hidden but its shell keeps running (`Ctrl+T` brings it back) |
| `Alt+1` | **Single + terminal layout** — keeps only the current window (or the last editor, if on the terminal) with the compact terminal panel below it |
| `Alt+2` | **Two windows layout** — keeps the current window (or the last editor, if on the terminal), closes the rest, and splits it into two 50/50 editor panes; the terminal is hidden but its shell keeps running (`Ctrl+T` brings it back) |
| `Alt+3` | **Two windows + terminal layout** — keeps the current window (or the last editor, if on the terminal), closes the rest, and recreates the default two 50/50 editor panes + compact terminal panel under the left one (restarting the shell if it had exited) |

All four presets leave the **Claude Code panel** (see below) as it was: if it
was showing, it is put back on the right after the preset is built; if it was
hidden, it stays hidden.  Claude keeps running either way.  A preset first
rejects any open Claude diff (an editor the diff borrowed gets its file back),
then builds the layout.

### Cycling

| Key | Action |
|-----|--------|
| `Ctrl+,` | **Cycle** between editor panels (skips the terminal and Claude panels; from either panel, jumps to an editor) |

### Terminal panel

| Key | Action |
|-----|--------|
| `Ctrl+T` | **Toggle focus** between terminal and last editor (from the Claude panel it goes to the terminal; from the terminal it always returns to an editor) |
| `Ctrl+Shift+T` | **Toggle focus + expand**: from editor → expand terminal and focus it; from terminal → collapse and return to editor |
| `Home` | **Toggle terminal height** between compact (6 lines) and expanded (~50% of screen) — Normal, Visual, Terminal |

When focusing the terminal, it auto-scrolls to the bottom and enters
**Terminal mode** (Insert mode for the shell).  Use `Ctrl+T` or `Ctrl+Shift+T`
to leave terminal mode and return to an editor.

**Recovery:** if the terminal window was closed (e.g. by `Alt+0`) or the shell
exited, `Ctrl+T`, `Ctrl+Shift+T`, and `Home` re-open the panel under the left
column and start a fresh shell as needed.  The first press after a recovery
focuses the terminal rather than toggling away from it.

Height changes are skipped when the terminal has no window above or below it
(e.g. when it sits side-by-side with an editor).

### Claude Code panel

A full-height [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
terminal on the right (30% of the width), connected to Neovim through
`claudecode.nvim`: Claude sees the current file and selection, can open files,
read diagnostics, and propose edits as diffs.  It needs the `claude` CLI on
`PATH`; nothing starts until you first open the panel.

| Key | Mode | Action |
|-----|------|--------|
| `Alt+C` | Normal, Insert, Terminal | **Toggle focus** between Claude and your last editor (from the shell it goes to Claude; from Claude it goes to the editor, never back to the shell) — starts Claude on first use, restarts it if it exited |
| `Alt+Shift+C` | Normal, Insert, Terminal | **Show / hide** the panel without moving focus (hiding from inside it returns you to the last editor) |
| `Alt+C` | Visual | **Send the selection** to Claude as an `@`-mention and focus Claude |
| `\ab` | Normal, in an editor | **Add the current file** to Claude's context |
| `\aa` / `\ad` | Normal, in a diff | **Accept / reject** Claude's proposed diff (see Diffs below for the other keys) |
| `\ar` / `\aC` | Normal, in an editor | Start Claude with `--resume` (pick a past session) / `--continue` (last session) |
| `\am` | Normal, in an editor | Pick a **model**, then start Claude with it |

The `\a…` keys are `<leader>` keys (`\` is the leader): press `\`, then `a`,
then the letter, within one second, **in Normal mode in an editor window**.  In
Insert mode they just type text, and inside the Claude panel they type into
Claude's prompt.  `\ar`, `\aC` and `\am` only affect a new session: if Claude
is already running they just focus it (use `/resume` or `/model`, or `Alt+P`,
inside Claude instead).

Leaving either terminal never lands in the other: `Ctrl+T` / `Ctrl+Shift+T`
from the shell, and `Alt+C` from Claude, go to the last editor you used, and
`Ctrl+,` from either panel jumps to an editor.

#### Typing inside the Claude panel

Focus in the panel means **Terminal mode**: keys go to Claude, so Claude
Code's own shortcuts work as in Windows Terminal (type `?` on an empty prompt
for its list).  `Enter`, `Shift+Enter`, `Ctrl+J`, `Shift+Tab`, `Alt+P`,
`Esc`, `Ctrl+R` and `Ctrl+O` were checked in this panel; the rest come from
that list:

| Key | In Claude |
|-----|-----------|
| `Enter` | Submit |
| `Shift+Enter` / `Ctrl+J` / `\` then `Enter` | **Newline** (`Shift+Enter` is remapped to `Ctrl+J` in this panel; Neovim's terminal would otherwise submit) |
| `Shift+Tab` | Cycle permission mode (auto → manual → accept edits → plan) |
| `Alt+P` | Switch model |
| `Esc` / `Esc Esc` | Interrupt Claude or close a menu / clear the input |
| `Ctrl+R` | Search prompt history |
| `Ctrl+O` | Toggle the detailed transcript |
| `Ctrl+G` | Edit the prompt in an external editor |
| `Ctrl+Shift+V` | **Paste** text from the clipboard (added by this config; Neovide has no terminal paste key) |
| `Alt+V` | Paste an image |
| `!`, `/`, `@` | Shell mode, commands, file mention |

These keys belong to this config, so Claude never receives them: `Alt+C`,
`Alt+Shift+C`, `Ctrl+T`, `Ctrl+Shift+T`, `Home`, `Ctrl+,`, `Alt+0`–`Alt+3`,
`Ctrl+=`/`Ctrl+-`/`Ctrl+0` and the `.nvimproject` `Ctrl+F*` keys.  That makes
Claude's own `Ctrl+T` (task list) unreachable in this panel.

These keys work however Neovide was started.  When it is launched from
Windows Terminal, Claude would otherwise inherit Windows Terminal's
`WT_SESSION` variable and stop understanding `Esc`, `Alt+…` and `Shift+Tab`,
so the panel starts Claude without it.  Running `claude` by hand in the
ordinary terminal panel does not get this treatment.

**Terminal mode vs Normal mode.**  Claude only receives keys while the panel
is in Terminal mode (`-- TERMINAL --` at the bottom).  Scrolling the mouse
wheel over the panel, or `Ctrl+\` `Ctrl+N`, switches it to Normal mode so you
can scroll back and copy (move, search, drag or `v` to select, `Ctrl+C`).  To
type again, click the panel, press `i`, or just press one of Claude's keys:
in this panel `Enter`, `Shift+Enter`, `Ctrl+J`, `Shift+Tab`, `Alt+P`,
`Alt+V`, `Ctrl+R`, `Ctrl+O` and `Ctrl+Shift+V` go straight back to Claude from
Normal mode.  Letters and `Esc` keep their Normal-mode meaning.  In Normal mode
`Ctrl+Shift+K` hides the panel, and `Ctrl+K`, `Ctrl+\` and `Alt+\` do
nothing.

**Hiding never ends the session.**  `Alt+Shift+C`, `Ctrl+Shift+K`, `:q` in the
panel, and the layout presets only close the window; the conversation is still
there when the panel comes back.  Only `:ClaudeCodeClose` stops Claude.  After
`/exit`, the panel shows `[Process exited 0]` and the next `Alt+C` starts a
fresh session in the same place.

Entering the panel (by `Alt+C` or a click) lands in Terminal mode, ready to
type.  It uses the same dark background as the shell panel, is not listed in
the `Ctrl+I` buffer picker, and is skipped by `Ctrl+,`, `Ctrl+Enter` and the
presets' choice of editor window.

**Diffs:** when Claude proposes an edit, it is shown inline and read-only:
removed lines in red and struck through, added lines in green, with `-`/`+`
in the sign column.  The cursor moves into it.

- **Two or more editors open:** no panel is added.  The diff borrows an
  editor: the one already showing that file if there is one, otherwise one
  you weren't working in.  When the diff closes, that editor gets its file
  back at the same cursor and scroll position.
- **One editor:** a panel opens beside it and closes afterwards.

| Key (in the diff) | Action |
|---|---|
| `Ctrl+S` or `\aa` | Accept |
| `Esc`, `Ctrl+G`, `Ctrl+[` | Reject (if a popup is open, the first press only closes it) |
| `\ad`, `Ctrl+K` | Reject |
| `Ctrl+Shift+K` | Reject; a borrowed editor stays open, a diff panel closes |
| `Alt+0`–`Alt+3` | Reject, then build the layout |

To change the proposal, reject it and tell Claude what to do differently.  The
terminal panel stays compact while the diff is open, and every window gets its
old size back when it closes.  (For side-by-side before/after panes that you
can edit before accepting, remove the `diff_opts = { layout = 'unified' }`
line from `plugins.lua`.  That view never borrows an editor and adds two
panels whenever the left editor shows a different file.)

Other commands: `:ClaudeCode` (show/hide + focus), `:ClaudeCodeStatus`,
`:ClaudeCodeClose`, `:ClaudeCodeCloseAllDiffs`, `:ClaudeCodeSendText {text}`.

---

## 7. LSP Features

### Info & diagnostics

| Key | Action |
|-----|--------|
| `Ctrl+M` | Show **diagnostic float** (errors/warnings first) or **LSP hover** info |
| `Ctrl+P` | Show **signature help** |
| `[d` | Go to **previous** diagnostic |
| `]d` | Go to **next** diagnostic |

Diagnostics display as **colored underlines only** — no inline virtual text, no
gutter signs.  Press `Ctrl+M` to see the full message.

All LSP floats are non-focusable: the cursor never gets trapped in them.

**Automatic signature help** (`lsp_signature.nvim`): while typing function
arguments, a bordered float shows the parameter list with the active parameter
highlighted.  It closes after 4 s of inactivity; no inline virtual-text hint is
shown.

### Go-to commands

| Key | Action |
|-----|--------|
| `gd` | Go to **definition** |
| `gD` | Go to **declaration** |
| `gi` | Go to **implementation** |
| `gr` | Find **references** |
| `gt` | Go to **type definition** |
| `Ctrl+Enter` | Go to **definition in the other editor panel** (splits if needed) |
| `Ctrl+Shift+Enter` | Go to **definition in same panel** |

When the server returns several definitions (e.g. `ols` on an `import` line),
`Ctrl+Enter` and `Ctrl+Shift+Enter` jump straight to the first match instead of
opening a quickfix list.

### Refactoring

| Key | Action |
|-----|--------|
| `Alt+R` | **Rename** symbol |
| `<leader>ca` | **Code action** |
| `<leader>f` | **Format** buffer (if server supports it) |

---

## 8. Completion (nvim-cmp)

Completion is **manual only** — no popup while typing.

| Key | Action |
|-----|--------|
| `Ctrl+N` | **Open** completion menu |
| `Down` / `Up` | Navigate suggestions |
| `Enter` | **Confirm** selected completion |
| `Esc` or `Ctrl+G` | **Close** completion menu |

---

## 9. Telescope (Fuzzy Finder)

| Key | Action |
|-----|--------|
| `Ctrl+Shift+I` | **Find files** (respects `.nvimproject` blacklist) |
| `Ctrl+I` | **Browse open buffers** (sorted by most recently used, current buffer excluded) |
| `Alt+F` | **Live grep** (search file contents) |
| `Ctrl+Shift+F` | **File browser** (directory tree at current file's location, or CWD; hidden files shown, `.gitignore` not respected) |

### Inside Telescope

| Key | Action |
|-----|--------|
| `Esc` / `Ctrl+G` / `Ctrl+[` | Close picker |
| `Ctrl+C` | Close picker (prompt/Insert mode only) |
| `Ctrl+R` | (File browser only) **Switch drive/path** — prompts for a new root |

Default ignore patterns: `node_modules/`, `.git/`, `*.lock`, `__pycache__/`,
`*.pyc`.  Additional patterns can be added per-project via `.nvimproject`.

---

## 10. The `.nvimproject` File

A `.nvimproject` file is a **Lua script** placed in the root of a project
directory.  When Neovim opens with that directory as CWD, the file is loaded
automatically at startup.

### Purpose

1. **Bind shell commands to function keys** — run build/test/serve commands
   with a single keypress, executed in the terminal panel.
2. **Configure Telescope ignore patterns** — hide build artifacts, vendor
   directories, etc. from file search.

### Syntax

The file must **return a Lua table**.  It supports two top-level keys:

```lua
return {
    -- Shell commands bound to Ctrl+F-keys
    -- Keys must be named "F1" through "F12" (F6 is reserved)
    F5  = "npm run dev",
    F7  = "npm run build",
    F8  = "npm test",

    -- Patterns to hide from Telescope file search
    blacklist_patterns = {
        "dist/",
        "%.min%.js$",
        "vendor/",
    },
}
```

Alternatively, commands can be nested under a `commands` key:

```lua
return {
    commands = {
        F5  = "python main.py",
        F7  = "python -m pytest",
    },
    blacklist_patterns = {
        "__pycache__/",
        "%.pyc$",
    },
}
```

### How command keys work

- Each `F<N>` entry binds `Ctrl+F<N>` in **all modes** (Normal, Visual,
  Insert, and Terminal).
- Pressing the key sends the command to the terminal panel: it clears the
  screen, `cd`s to the project directory, and runs the command.
- `F6` is reserved: once a `.nvimproject` is loaded, `Ctrl+F6` sends
  **Ctrl+C** (interrupt) to the terminal in all modes, useful for stopping a
  running process.  An `F6` entry in the file is ignored.
- If the shell is not running, the command is not sent and a warning is shown
  (`Ctrl+T` restarts it).

### Blacklist patterns

The `blacklist_patterns` array uses Lua patterns (not globs).  They are
**appended** to the default ignore list, not replacing it.  Common patterns:

| Pattern | Matches |
|---------|---------|
| `"dist/"` | Any path containing `dist/` |
| `"%.min%.js$"` | Files ending in `.min.js` |
| `"build/"` | Any path containing `build/` |

### Requirements

- The file must be named exactly `.nvimproject` (with the leading dot).
- It must be in the **current working directory** when Neovim starts.
- It must be valid Lua that returns a table.
- If parsing fails, an error notification is shown and no keys are bound.

---

## 11. Editor Settings

| Setting | Value |
|---------|-------|
| Indentation | 4 spaces (enforced on all filetypes except Odin, which uses tabs at width 4) |
| Word wrap | Off by default (toggle with `Alt+W`) |
| Line numbers | Relative + absolute |
| Clipboard | System clipboard (`unnamedplus`) |
| Search | Incremental + highlight (clear with `Esc`) |
| Comment continuation | Disabled (Enter in a comment does not auto-insert `//`, `#`, etc.) |
| Font | JetBrains Mono, size 10 |
| Colorscheme | Naysayer (Gruvbox is installed but not active) |
| Terminal panel | Dark teal background (`#001012`) to set it apart from editors |
| Horizontal scroll | Smooth (`sidescroll=1`, 8-column margin) |
| Shada (history) | Remembers 1000 files of marks/history |

---

## 12. Neovide-Specific

| Key | Action |
|-----|--------|
| `F11` | Toggle **fullscreen** (Normal mode) |
| `Ctrl+=` | **Increase** font size by 1 |
| `Ctrl+-` | **Decrease** font size by 1 |
| `Ctrl+0` | **Reset** font size to default (10) |

The font-size keys work in Normal, Visual, Insert, and Terminal mode, and
re-balance the window layout (keeping the terminal's compact/expanded state)
after resizing.

Neovide settings:
- Cursor animation: 75ms
- Scroll animation: 125ms
- Cursor trail: 0.2

Highlights are always drawn opaque.  The Naysayer theme marks some groups
(diff lines, matching brackets, inactive status lines) with a `blend` value,
which Neovide would render as see-through pixels showing the desktop behind
the window.  `plugins.lua` mixes that blend into the colour instead, so the
colours are the same but solid.

---

## 13. Installed Language Servers

These are auto-installed via Mason on first launch:

| Server | Language |
|--------|----------|
| `ts_ls` | TypeScript / JavaScript |
| `eslint` | JS/TS linting |
| `cssls` | CSS |
| `html` | HTML |
| `pyright` | Python |
| `clangd` | C / C++ |
| `gopls` | Go |
| `ols` | Odin (collections `core`, `vendor`, `base` from `C:\Odin`; formats with tabs) |
| `lua_ls` | Lua |
