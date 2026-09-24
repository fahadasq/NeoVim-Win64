# Portable Neovim + Neovide Setup (Windows)

Self-contained Neovim distribution for Windows: binary, config, data, and GUI
(Neovide) all live under one directory with no external dependencies beyond a
system-installed font and Git.

## Directory layout

```
nvim-win64/                   ← repo root
├── nvim.bat                  ← launcher: sets XDG vars, starts Neovide+Nvim
├── neovide.exe               ← Neovide GUI binary
├── nvim/bin/                 ← Neovim binary + support DLLs (nvim.exe, win32yank, etc.)
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
5. `require("windows")` — startup vsplit + terminal layout, kill-buffer, goto-def
6. `require("telescope_bindings")` — Ctrl+I/Ctrl+Shift+I/Alt+F/Ctrl+Shift+F
7. `require("lsp")` — Mason auto-install, per-server config, diagnostics
8. `require("completion")` — nvim-cmp manual-trigger setup

## Plugins (lazy.nvim)

| Plugin | Purpose |
|--------|---------|
| `rafamadriz/gruvbox` | Gruvbox colorscheme |
| `lukas-reineke/indent-blankline.nvim` | Indent guide lines |
| `nvim-telescope/telescope.nvim` | Fuzzy finder (files, buffers, grep) |
| `nvim-telescope/telescope-file-browser.nvim` | Directory browser in Telescope |
| `numToStr/Comment.nvim` | Comment toggling |
| `nvim-treesitter/nvim-treesitter` | Syntax highlighting + indent (lua, js, c, html, css, scss, ts, svelte) |
| `williamboman/mason.nvim` + `mason-lspconfig.nvim` | LSP server installer |
| `neovim/nvim-lspconfig` | LSP client configs |
| `hrsh7th/nvim-cmp` + `cmp-nvim-lsp` | Completion engine (manual trigger) |

## LSP servers (auto-installed via Mason)

`ts_ls`, `eslint`, `cssls`, `html`, `pyright`, `clangd`, `gopls`, `lua_ls`

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
- **`.nvimproject` files** — per-project Lua files that bind shell commands to
  Ctrl+F-key shortcuts and configure Telescope ignore patterns.  See
  `terminal.lua:load_project()`.
- **Manual completion** — nvim-cmp popup only appears on explicit Ctrl+N; no
  auto-popup while typing.
- **Diagnostics as underlines only** — no virtual text, no gutter signs; float
  shown on Ctrl+M.
- **No comment continuation** — `formatoptions` strips `c`, `r`, `o` on every
  FileType event so pressing Enter in a comment block does not auto-insert
  comment leaders.

## Editing guidelines for future changes

- All user-facing keybindings are in `keymaps.lua`, `windows.lua`,
  `telescope_bindings.lua`, and `lsp.lua:on_attach()`.  Don't scatter bindings
  across other files.
- `options.lua` has a FileType autocmd that enforces indent settings and
  formatoptions globally — filetype-specific overrides need to go *after* this
  autocmd or use a higher-priority autocmd.
- The terminal module (`terminal.lua`) exports state (`term_buf`, `term_win`,
  `term_chan`, `last_editor_win`, `expanded`) that `windows.lua` depends on.
  Don't restructure one without the other.
- Plugin list is minimal by design.  Don't add statusline, bufferline, or
  dashboard plugins — the config intentionally omits them.
