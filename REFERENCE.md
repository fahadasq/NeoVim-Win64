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
| `Ctrl+S` | **Save** file (creates missing directories with confirmation) — Normal, Insert, Visual |
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
| `Ctrl+K` | **Kill buffer** — closes the current buffer (won't close terminal) |
| `Ctrl+Shift+K` | **Close window** — with confirmation (won't close terminal) |
| `Alt+0` | **Single window layout** — keeps only the current window (or the last editor, if on the terminal); the terminal is hidden but its shell keeps running (`Ctrl+T` brings it back) |
| `Alt+1` | **Single + terminal layout** — keeps only the current window (or the last editor, if on the terminal) with the compact terminal panel below it |
| `Alt+2` | **Two windows layout** — keeps the current window (or the last editor, if on the terminal), closes the rest, and splits it into two 50/50 editor panes; the terminal is hidden but its shell keeps running (`Ctrl+T` brings it back) |
| `Alt+3` | **Two windows + terminal layout** — keeps the current window (or the last editor, if on the terminal), closes the rest, and recreates the default two 50/50 editor panes + compact terminal panel under the left one (restarting the shell if it had exited) |

### Cycling

| Key | Action |
|-----|--------|
| `Ctrl+,` | **Cycle** between editor panels (skips terminal) |

### Terminal panel

| Key | Action |
|-----|--------|
| `Ctrl+T` | **Toggle focus** between terminal and last editor |
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
