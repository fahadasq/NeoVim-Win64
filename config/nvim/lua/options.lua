-- lua/options.lua

-- ─── Clipboard  ─────────────────────────────────────────────────────────────

vim.opt.clipboard    = "unnamedplus"

-- ─── Line Numbers  ───────────────────────────────────────────────────────────

vim.wo.number         = true
vim.wo.relativenumber = true

-- ─── Neovide Fonts────────────────────────────────────────────────────────────

local font_name = "JetBrains Mono"
vim.o.guifont = font_name .. ":h10"

-- ─── Other Neovide Graphics ──────────────────────────────────────────────────

vim.g.neovide_cursor_animation_length = 0.075
vim.g.neovide_scroll_animation_length = 0.125
vim.g.neovide_cursor_trail_size = 0.2

-- ─── Indentation ─────────────────────────────────────────────────────────────

vim.opt.expandtab   = true
vim.opt.shiftwidth  = 4
vim.opt.tabstop     = 4
vim.opt.softtabstop = 4
vim.opt.autoindent  = true
vim.opt.smartindent = true

-- ─── Word wrap OFF by default ────────────────────────────────────────────────
-- Horizontal scrolling is enabled; the view pans as the cursor moves.

vim.opt.wrap          = false
vim.opt.sidescroll    = 1
vim.opt.sidescrolloff = 8

-- ─── Search ──────────────────────────────────────────────────────────────────

vim.opt.hlsearch  = true
vim.opt.incsearch = true

-- ─── Shada / MRU ─────────────────────────────────────────────────────────────

vim.opt.shada = "!,'1000,<50,s10,h"

-- ─── Enforce indent + no comment continuation after ALL filetype plugins ─────
--
-- Many bundled filetype plugins (css, scss, lua, etc.) set their own
-- shiftwidth and re-add 'r'/'o' to formatoptions.  This autocmd fires last
-- (BufEnter covers both initial load and switching to an already-open buffer)
-- and forcibly re-applies our preferences.

vim.api.nvim_create_autocmd({ 'FileType' }, {
  pattern  = '*',
  callback = function()
    vim.opt_local.expandtab   = true
    vim.opt_local.shiftwidth  = 4
    vim.opt_local.tabstop     = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.formatoptions:remove({ 'c', 'r', 'o' })
  end,
})
