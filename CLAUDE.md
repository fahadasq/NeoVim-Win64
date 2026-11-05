# Portable Neovim + Neovide Setup (Windows)

Self-contained Neovim distribution for Windows: binary, config, data, and GUI
(Neovide) all live under one directory with no external dependencies beyond a
system-installed font and Git (plus, optionally, the `claude` CLI on `PATH` for
the Claude Code panel).

## Directory layout

```
nvim-win64/                   ← repo root
├── nvim.bat                  ← launcher: sets XDG vars, starts Neovide+Nvim
├── neovide.exe               ← Neovide GUI binary
├── nvim/bin/                 ← Neovim binary + support DLLs (nvim.exe, win32yank, etc.)
├── ols/                      ← patched OLS build (ols.exe + builtin/) used instead of Mason's; see build-tags-fix.patch
├── config/nvim/              ← XDG_CONFIG_HOME/nvim  (the Neovim config)
│   ├── init.lua              ← entry point: bootstraps lazy.nvim, loads modules
│   ├── lazy-lock.json        ← plugin lock file (lazy.nvim)
│   ├── create.file           ← empty placeholder (touched by file-creation flows)
│   ├── fonts/                ← bundled JetBrains Mono font
│   └── lua/
│       ├── plugins.lua       ← lazy.nvim plugin specs
│       ├── options.lua       ← editor options (indent, wrap, clipboard, Neovide)
│       ├── keymaps.lua       ← all non-window, non-telescope keybindings
│       ├── windows.lua       ← window/panel management, startup layout, goto-def
│       ├── terminal.lua      ← terminal panel, .nvimproject loader, focus/height
│       ├── claude_panel.lua  ← Claude Code panel; custom terminal provider for claudecode.nvim
│       ├── telescope_bindings.lua  ← file finder, buffer picker, grep, file browser
│       ├── lsp.lua           ← Mason + LSP server config + diagnostic display
│       └── completion.lua    ← nvim-cmp: manual-trigger completion (Ctrl+N)
├── data/nvim-data/           ← XDG_DATA_HOME/nvim-data (gitignored; Mason, lazy, shada)
└── .gitignore                ← ignores data/, logs, OS junk
```

## How it starts

`nvim.bat` sets `XDG_CONFIG_HOME` and `XDG_DATA_HOME` relative to itself, then
launches **Neovide** pointing at the local `nvim.exe`.  This makes the whole
tree portable — move the folder and everything still works.

## Config module load order (init.lua)

1. Bootstrap **lazy.nvim** into `stdpath("data")/lazy/lazy.nvim`
2. `require("lazy").setup(require("plugins"))` — installs/loads plugins
3. `require("options")` — indent, wrap, clipboard, font, Neovide graphics
4. `require("keymaps")` — movement, deletion, save, escape, comment, file ops
5. `require("windows")` — startup vsplit + terminal layout, kill-buffer, goto-def,
   Claude panel keys (loads `terminal`, then `claude_panel`)
6. `require("telescope_bindings")` — Ctrl+I/Ctrl+Shift+I/Alt+F/Ctrl+Shift+F
7. `require("lsp")` — Mason auto-install, per-server config, diagnostics
8. `require("completion")` — nvim-cmp manual-trigger setup

## Plugins (lazy.nvim)

| Plugin | Purpose |
|--------|---------|
| `rafamadriz/gruvbox` | Gruvbox colorscheme (installed, not active) |
| `alljokecake/naysayer-theme.nvim` | Active colorscheme.  Its `before_highlight` hook bakes each group's `blend` into `bg` and drops the attribute, because Neovide renders `blend` as see-through pixels (diff lines, MatchParen) |
| `lukas-reineke/indent-blankline.nvim` | Indent guide lines |
| `RRethy/vim-illuminate` | Highlight references of word under cursor; Shift+J/K jump (no wrap) |
| `nvim-telescope/telescope.nvim` | Fuzzy finder (files, buffers, grep) |
| `nvim-telescope/telescope-file-browser.nvim` | Directory browser in Telescope |
| `numToStr/Comment.nvim` | Comment toggling |
| `nvim-treesitter/nvim-treesitter` | Syntax highlighting + indent (lua, js, c, html, css, scss, ts, svelte) |
| `williamboman/mason.nvim` + `mason-lspconfig.nvim` | LSP server installer |
| `neovim/nvim-lspconfig` | LSP client configs |
| `hrsh7th/nvim-cmp` + `cmp-nvim-lsp` | Completion engine (manual trigger) |
| `coder/claudecode.nvim` | Claude Code IDE bridge (MCP WebSocket server, selection, diffs); terminal supplied by `claude_panel.lua`, loaded on `VeryLazy`; diffs use the inline `unified` layout (one extra panel) |

## LSP servers (auto-installed via Mason)

`ts_ls`, `eslint`, `cssls`, `html`, `pyright`, `clangd`, `gopls`, `lua_ls`, `ols`

`ols` is still installed by Mason, but `lsp.lua` points its `cmd` at the
patched `ols/ols.exe`.  Upstream OLS (nightly-2026-09-20) ORs separate
`#+build` lines instead of ANDing them, so `_other.odin` files such as
`core:time`'s `time_other.odin` get indexed on Windows and goto-definition
jumps there instead of the `_windows.odin` version.  To rebuild on a newer OLS:
apply `ols/build-tags-fix.patch` to the OLS source and run `build.bat` (or
drop the `cmd` override once upstream has the fix).

## Key architecture decisions

- **Portable via XDG overrides** — `nvim.bat` sets XDG_CONFIG_HOME and
  XDG_DATA_HOME to local paths; no `%LOCALAPPDATA%` dependency.
- **Neovide as GUI** — the setup is designed for Neovide (smooth scrolling,
  cursor animation, `guifont`). Terminal Neovim would work but loses GUI
  features and some keybindings (`<C-S-*>`, `<F11>` fullscreen).
- **Camel-case-aware movement** — custom `keymaps.lua` functions split
  identifiers at camelCase, digit, and symbol boundaries (not just whitespace/
  WORD).  Treesitter leaf-node movement is layered on top (Shift+H/L).
- **Terminal panel is permanent** — a bottom-of-screen shell panel created at
  startup; cannot be closed, only toggled in height/focus.
- **Claude Code panel** — `claudecode.nvim` runs `claude` through a custom
  terminal provider (`claude_panel.lua`'s `M.provider`), not snacks.nvim or the
  plugin's native split.  The panel mirrors the shell panel: unlisted buffer,
  `TermPanelNormal` styling, full-height column on the right with
  `winfixwidth`, hidden (never killed) when its window closes, rebuilt or
  restarted on demand.  Layout presets put it back if it was showing, and
  first reject any open Claude diff (`windows.lua:keep_claude()`).  Only
  `:ClaudeCodeClose` ends the session.  The plugin sets no keymaps; the
  Claude keys are in `windows.lua`, apart from the buffer-local ones noted
  under "Editing guidelines".  It writes `~/.claude/ide/<port>.lock`, outside
  the portable tree, so the CLI can find Neovim.  `claude` is started with
  Neovim's environment minus `WT_SESSION`, `WT_PROFILE_ID`, `TERM_PROGRAM`
  and `TERM_PROGRAM_VERSION` (`claude_panel.lua:job_env()`): when Neovide is
  launched from Windows Terminal, `WT_SESSION` makes `claude` expect Windows
  Terminal's key encoding, and Esc, Alt+keys and Shift+Tab stop working.
- **`.nvimproject` files** — per-project Lua files that bind shell commands to
  Ctrl+F-key shortcuts and configure Telescope ignore patterns.  See
  `terminal.lua:load_project()`.
- **Manual completion** — nvim-cmp popup only appears on explicit Ctrl+N; no
  auto-popup while typing.
- **Diagnostics as underlines** — no virtual text, no gutter signs; float
  shown on Ctrl+M.  The line an error starts on also gets a full-width
  `DiagnosticErrorLine` background, set by a custom `error_line` diagnostic
  handler in `lsp.lua` (the built-in `signs.linehl` would open the sign column).
- **No comment continuation** — `formatoptions` strips `c`, `r`, `o` on every
  FileType event so pressing Enter in a comment block does not auto-insert
  comment leaders.

## Editing guidelines for future changes

- All user-facing keybindings are in `keymaps.lua`, `windows.lua`,
  `telescope_bindings.lua`, and `lsp.lua:on_attach()`.  Don't scatter bindings
  across other files.  (Exception: the Claude buffer's own keys are
  buffer-local, created with the buffer in `claude_panel.lua:setup_buf()`:
  Terminal-mode `Ctrl+Shift+V` paste and `Shift+Enter` newline, plus
  Normal-mode maps that send Claude's keys (`Enter`, `Ctrl+J`, `Shift+Tab`,
  `Alt+P`, ...) back to Claude and a click that resumes typing, because a
  mouse-wheel scroll or click drops the panel into Normal mode.  Likewise
  each Claude diff proposal buffer gets Normal-mode `Esc` / `Ctrl+G` /
  `Ctrl+[` = reject, set in `claude_panel.lua`'s `ClaudeCodeDiffOpened`
  handler.  And the shell buffer's `PageUp` / `PageDown`, which scroll its
  scrollback instead of walking shell history, are buffer-local, set in
  `terminal.lua:set_scroll_keys()` when the shell starts.)
- `options.lua` has a FileType autocmd that enforces indent settings and
  formatoptions globally — filetype-specific overrides need to go *after* this
  autocmd or use a higher-priority autocmd.
- The terminal module (`terminal.lua`) exports state (`term_buf`, `term_win`,
  `term_chan`, `last_editor_win`, `expanded`) that `windows.lua` depends on.
  Don't restructure one without the other.
- `claude_panel.lua` exports `is_win`, `is_buf`, `is_visible`, `hide`,
  `reattach`, `focus_toggle`, `toggle_visible`, `is_diff_host` and
  `provider`.  (`is_diff_host` is what makes Ctrl+Shift+K reject a diff
  instead of closing a borrowed editor.)  `windows.lua`
  uses them to keep editor-only logic (presets, Ctrl+Enter, Ctrl+K, splits)
  off the Claude window, and `terminal.lua`'s `is_editor()` (used by
  Ctrl+T, Ctrl+Shift+T and Ctrl+,) excludes it.  It reuses
  `terminal.style_term_win`, `terminal.set_height` and
  `terminal.last_editor_win`.  `last_editor_win` must only ever hold a real
  editor (never the shell or Claude), or Ctrl+T / Alt+C ping-pong between the
  two terminals.  New code that iterates "editor" windows should skip
  `claude.is_win(w)` as well as the terminal window.
- The provider must not define `ensure_visible`: the plugin calls that with
  no arguments, so a first start would have no command or environment.
- Diff borrowing (`claude_panel.lua`, "Diffs" section): with 2+ editors, the
  `ClaudeCodeDiffOpened` handler moves the plugin's inline diff buffer into
  an existing editor, closes the plugin's split, and clears `new_window` /
  `new_buffer` in the plugin's diff state so its cleanup neither closes that
  split nor deletes the buffer (deleting it would close the borrowed editor).
  `ClaudeCodeDiffClosed` gives the editor its buffer back.  This uses plugin
  internals (`diff._get_active_diffs()`, `diff._restore_window_sizes()`, the
  state's `new_window` / `new_buffer` / `window_sizes` / `layout` fields), so
  re-check it when updating claudecode.nvim.  It also clears the proposal's
  'modified' flag: Neovim won't take a modified `bufhidden=wipe` buffer out
  of a window (E37).
- A custom `terminal_cmd` is split with POSIX rules (backslash escapes), so
  write Windows paths with forward slashes.
- Plugin list is minimal by design.  Don't add statusline, bufferline, or
  dashboard plugins — the config intentionally omits them.
