-- lua/keymaps.lua

-- ─── Character classifier ─────────────────────────────────────────────────────

local function ctype(line, i)
  if i < 0 or i >= #line then return 's' end
  local c = line:sub(i + 1, i + 1)
  if     c:match('%s') then return 's'
  elseif c:match('%u') then return 'U'
  elseif c:match('%l') then return 'l'
  elseif c:match('%d') then return 'd'
  else                       return 'x'
  end
end

local function is_boundary(line, i)
  local prev = ctype(line, i - 1)
  local curr = ctype(line, i)
  if curr == 's'                                   then return false end
  if curr == 'x'                                   then return true  end
  if prev == 'x'                                   then return true  end
  if prev == 's'                                   then return true  end
  if prev == 'l' and curr == 'U'                   then return true  end
  if (prev == 'l' or prev == 'U') and curr == 'd'  then return true  end
  if prev == 'd' and (curr == 'l' or curr == 'U')  then return true  end
  return false
end

local function next_boundary(line, ccol)
  for i = ccol + 1, #line - 1 do
    if is_boundary(line, i) then return i end
  end
  return nil
end

local function prev_boundary(line, ccol)
  for i = ccol - 1, 0, -1 do
    if is_boundary(line, i) then return i end
  end
  return nil
end

-- ─── Camel / alphanumeric + special movement ─────────────────────────────────

local function move_camel_right()
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(0, crow - 1, crow, false)[1]
  local b = next_boundary(line, ccol)
  if b ~= nil then
    vim.api.nvim_win_set_cursor(0, { crow, b })
  elseif crow < vim.api.nvim_buf_line_count(0) then
    local nxt = vim.api.nvim_buf_get_lines(0, crow, crow + 1, false)[1]
    local nb  = next_boundary(nxt, -1)
    vim.api.nvim_win_set_cursor(0, { crow + 1, nb ~= nil and nb or 0 })
  end
end

local function move_camel_left()
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(0, crow - 1, crow, false)[1]
  local b = prev_boundary(line, ccol)
  if b ~= nil then
    vim.api.nvim_win_set_cursor(0, { crow, b })
  elseif ccol > 0 then
    vim.api.nvim_win_set_cursor(0, { crow, 0 })
  elseif crow > 1 then
    local prev = vim.api.nvim_buf_get_lines(0, crow - 2, crow - 1, false)[1]
    vim.api.nvim_win_set_cursor(0, { crow - 1, math.max(0, #prev - 1) })
  end
end

-- ─── Treesitter leaf-node movement ───────────────────────────────────────────

local function ts_leaf_after(row0, col0)
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok then return nil end
  local ok2, tree = pcall(function() return parser:parse()[1] end)
  if not ok2 or not tree then return nil end
  local root = tree:root()
  local best = nil
  local function walk(node)
    if node:child_count() == 0 then
      local sr, sc = node:start()
      if sr > row0 or (sr == row0 and sc > col0) then
        if not best then best = node
        else
          local br, bc = best:start()
          if sr < br or (sr == br and sc < bc) then best = node end
        end
      end
    end
    for child in node:iter_children() do walk(child) end
  end
  walk(root)
  if best then local r, c = best:start() ; return { r + 1, c } end
end

local function ts_leaf_before(row0, col0)
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok then return nil end
  local ok2, tree = pcall(function() return parser:parse()[1] end)
  if not ok2 or not tree then return nil end
  local root = tree:root()
  local best = nil
  local function walk(node)
    if node:child_count() == 0 then
      local sr, sc = node:start()
      if sr < row0 or (sr == row0 and sc < col0) then
        if not best then best = node
        else
          local br, bc = best:start()
          if sr > br or (sr == br and sc > bc) then best = node end
        end
      end
    end
    for child in node:iter_children() do walk(child) end
  end
  walk(root)
  if best then local r, c = best:start() ; return { r + 1, c } end
end

local function move_token_right()
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local pos = ts_leaf_after(crow - 1, ccol)
  if pos then vim.api.nvim_win_set_cursor(0, pos) else move_camel_right() end
end

local function move_token_left()
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local pos = ts_leaf_before(crow - 1, ccol)
  if pos then vim.api.nvim_win_set_cursor(0, pos) else move_camel_left() end
end

-- ─── Deletion helpers ────────────────────────────────────────────────────────

local function buf_delete(sr, sc, er, ec)
  vim.api.nvim_buf_set_text(0, sr, sc, er, ec, {})
end

local function delete_camel_right()
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local line       = vim.api.nvim_buf_get_lines(0, crow - 1, crow, false)[1]
  local ecol       = math.min(ccol, #line)
  local b          = next_boundary(line, ecol)
  if b ~= nil then
    buf_delete(crow - 1, ecol, crow - 1, b) ; return
  end
  local total = vim.api.nvim_buf_line_count(0)
  if crow >= total then
    if ecol < #line then buf_delete(crow - 1, ecol, crow - 1, #line) end ; return
  end
  local nxt = vim.api.nvim_buf_get_lines(0, crow, crow + 1, false)[1]
  local nb  = next_boundary(nxt, -1)
  buf_delete(crow - 1, ecol, crow, nb ~= nil and nb or #nxt)
end

local function delete_camel_left()
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local line       = vim.api.nvim_buf_get_lines(0, crow - 1, crow, false)[1]
  local ecol       = math.min(ccol, #line)
  local b          = prev_boundary(line, ecol)
  if b ~= nil then
    buf_delete(crow - 1, b, crow - 1, ecol)
    vim.api.nvim_win_set_cursor(0, { crow, b }) ; return
  end
  if ecol > 0 then
    buf_delete(crow - 1, 0, crow - 1, ecol)
    vim.api.nvim_win_set_cursor(0, { crow, 0 }) ; return
  end
  if crow > 1 then
    local prev_line = vim.api.nvim_buf_get_lines(0, crow - 2, crow - 1, false)[1]
    local pb        = prev_boundary(prev_line, #prev_line)
    local del_from  = pb ~= nil and pb or 0
    buf_delete(crow - 2, del_from, crow - 1, 0)
    vim.api.nvim_win_set_cursor(0, { crow - 1, del_from })
  end
end

local function delete_token_right()
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local pos = ts_leaf_after(crow - 1, ccol)
  if pos then buf_delete(crow - 1, ccol, pos[1] - 1, pos[2]) else delete_camel_right() end
end

local function delete_token_left()
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local pos = ts_leaf_before(crow - 1, ccol)
  if pos then
    buf_delete(pos[1] - 1, pos[2], crow - 1, ccol)
    vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] })
  else
    delete_camel_left()
  end
end

local function delete_current_token()
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local row0, col0 = crow - 1, ccol
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok then delete_camel_right() ; return end
  local ok2, tree = pcall(function() return parser:parse()[1] end)
  if not ok2 or not tree then delete_camel_right() ; return end
  local target = nil
  local function find_leaf(node)
    local sr, sc, er, ec = node:range()
    local in_range = (sr < row0 or (sr == row0 and sc <= col0))
                 and (er > row0 or (er == row0 and ec > col0))
    if not in_range then return end
    if node:child_count() == 0 then target = node
    else for child in node:iter_children() do find_leaf(child) end end
  end
  find_leaf(tree:root())
  if target and target:is_named() then
    local sr, sc, er, ec = target:range()
    buf_delete(sr, sc, er, ec)
  else
    delete_camel_right()
  end
end

-- ─── Insert-mode boundary deletion ───────────────────────────────────────────
--
-- In insert mode the cursor sits BETWEEN characters; col() is 1-indexed and
-- points to the character to the RIGHT of the cursor.  We convert to 0-indexed
-- for our helpers, perform the deletion on the buffer directly, then leave the
-- cursor in place (nvim_buf_set_text keeps it correct automatically).

local function insert_delete_camel_left()
  -- col('.') in insert mode returns the column of the character to the right
  -- of the cursor, 1-indexed.  So the cursor is logically at col-1 (0-indexed).
  local crow    = vim.api.nvim_win_get_cursor(0)[1]
  local col1    = vim.fn.col('.')          -- 1-indexed, char to the right
  local ccol    = col1 - 1                 -- 0-indexed cursor position
  local line    = vim.api.nvim_buf_get_lines(0, crow - 1, crow, false)[1]
  local ecol    = math.min(ccol, #line)
  local b       = prev_boundary(line, ecol)
  if b ~= nil then
    buf_delete(crow - 1, b, crow - 1, ecol)
  elseif ecol > 0 then
    buf_delete(crow - 1, 0, crow - 1, ecol)
  elseif crow > 1 then
    local prev_line = vim.api.nvim_buf_get_lines(0, crow - 2, crow - 1, false)[1]
    local pb        = prev_boundary(prev_line, #prev_line)
    local del_from  = pb ~= nil and pb or 0
    buf_delete(crow - 2, del_from, crow - 1, 0)
  end
end

local function insert_delete_token_left()
  local crow    = vim.api.nvim_win_get_cursor(0)[1]
  local col1    = vim.fn.col('.')
  local ccol    = col1 - 1
  local pos     = ts_leaf_before(crow - 1, ccol)
  if pos then
    buf_delete(pos[1] - 1, pos[2], crow - 1, ccol)
  else
    insert_delete_camel_left()
  end
end

-- ─── Close any open floating windows ─────────────────────────────────────────
--
-- Used by Escape and its aliases so that diagnostic/hover floats are dismissed
-- without needing to move the cursor.

local function close_floats()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= '' then   -- relative ~= '' means it is a floating window
      vim.api.nvim_win_close(win, false)
    end
  end
end

-- ─── Save ────────────────────────────────────────────────────────────────────

local function smart_save()
  local filepath = vim.fn.expand('%:p')
  if filepath == '' then vim.cmd('write') ; return end
  local dir = vim.fn.fnamemodify(filepath, ':h')
  if vim.fn.isdirectory(dir) == 0 then
    vim.ui.input(
      { prompt = "Directory '" .. dir .. "' does not exist. Create it? [y/N]: " },
      function(answer)
        if answer and answer:lower() == 'y' then
          vim.fn.mkdir(dir, 'p') ; vim.cmd('write')
        else
          vim.notify('Save cancelled.', vim.log.levels.INFO)
        end
      end
    )
  else
    vim.cmd('write')
  end
end

-- ─── Word-wrap toggle ────────────────────────────────────────────────────────

local function toggle_wrap()
  local w = vim.api.nvim_get_option_value('wrap', { win = 0 })
  vim.api.nvim_set_option_value('wrap', not w, { win = 0 })
  vim.notify('Word wrap ' .. (not w and 'OFF' or 'ON'), vim.log.levels.INFO)
end

-- ─── Comment toggle ──────────────────────────────────────────────────────────

local function comment_toggle_line()
  require('Comment.api').toggle.linewise.current()
end

local function comment_toggle_visual()
  local esc = vim.api.nvim_replace_termcodes('<ESC>', true, false, true)
  vim.api.nvim_feedkeys(esc, 'nx', false)
  require('Comment.api').toggle.linewise(vim.fn.visualmode())
end

-- ─── File operations ─────────────────────────────────────────────────────────

local function rename_file()
  local old = vim.fn.expand('%:p')
  if old == '' then
    vim.notify('Buffer has no file name.', vim.log.levels.WARN) ; return
  end
  vim.ui.input({ prompt = 'Rename to: ', default = vim.fn.expand('%:.') },
    function(new_rel)
      if not new_rel or new_rel == '' then return end
      local new = vim.fn.fnamemodify(new_rel, ':p')
      local dir = vim.fn.fnamemodify(new, ':h')
      if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, 'p') end
      local ok, err = vim.loop.fs_rename(old, new)
      if ok then
        vim.cmd('edit ' .. vim.fn.fnameescape(new))
        vim.notify('Renamed to ' .. new_rel, vim.log.levels.INFO)
      else
        vim.notify('Rename failed: ' .. tostring(err), vim.log.levels.ERROR)
      end
    end)
end

local function delete_file()
  local path = vim.fn.expand('%:p')
  if path == '' then
    vim.notify('Buffer has no file name.', vim.log.levels.WARN) ; return
  end
  vim.ui.input(
    { prompt = "Delete '" .. vim.fn.expand('%:.') .. "'? [y/N]: " },
    function(answer)
      if not answer or answer:lower() ~= 'y' then return end
      local ok, err = vim.loop.fs_unlink(path)
      if ok then
        vim.cmd('bdelete!')
        vim.notify('Deleted ' .. path, vim.log.levels.INFO)
      else
        vim.notify('Delete failed: ' .. tostring(err), vim.log.levels.ERROR)
      end
    end)
end

-- ─── Movement keybindings ────────────────────────────────────────────────────

vim.keymap.set({ 'n', 'v' }, '<C-l>',   move_camel_right,  { noremap = true, silent = true })
vim.keymap.set({ 'n', 'v' }, '<C-h>',   move_camel_left,   { noremap = true, silent = true })
vim.keymap.set({ 'n', 'v' }, '<S-l>',   move_token_right,  { noremap = true, silent = true })
vim.keymap.set({ 'n', 'v' }, '<S-h>',   move_token_left,   { noremap = true, silent = true })
vim.keymap.set({ 'n', 'v' }, '<C-S-l>', '$',               { noremap = true })
vim.keymap.set({ 'n', 'v' }, '<C-S-h>', '^',               { noremap = true })

-- ─── Normal mode deletion ────────────────────────────────────────────────────

vim.keymap.set('n', '<C-d>',    delete_camel_right,   { noremap = true, silent = true })
vim.keymap.set('n', '<C-BS>',   delete_camel_left,    { noremap = true, silent = true })
vim.keymap.set('n', '<S-d>',    delete_token_right,   { noremap = true, silent = true })
vim.keymap.set('n', '<S-BS>',   delete_token_left,    { noremap = true, silent = true })
vim.keymap.set('n', '<C-S-d>',  'D',                  { noremap = true })
vim.keymap.set('n', '<C-S-BS>', 'd^',                 { noremap = true })
vim.keymap.set('n', '<A-d>',    delete_current_token, { noremap = true, silent = true })

-- ─── Normal mode basic editing ───────────────────────────────────────────────
--
-- Space   →  insert a space at the cursor and stay in normal mode
-- BS      →  delete character to the left (like Shift+X / 'X')

vim.keymap.set('n', '<Space>', 'i<Space><Esc>l', { noremap = true })
vim.keymap.set('n', '<BS>',    'X',              { noremap = true })

-- ─── Insert mode deletion ────────────────────────────────────────────────────
--
-- Mirrors the normal-mode boundary deletions so typing flow is uninterrupted.
-- <C-BS>  →  delete back to previous camel/special boundary
-- <S-BS>  →  delete back to previous token boundary (with camel fallback)

vim.keymap.set('i', '<C-BS>', insert_delete_camel_left, { noremap = true, silent = true })
vim.keymap.set('i', '<S-BS>', insert_delete_token_left, { noremap = true, silent = true })

-- ─── Re-indent selection ─────────────────────────────────────────────────────

vim.keymap.set('v', '<C-y>', '=', { noremap = true, silent = true, desc = 'Re-indent selection' })

-- ─── Scroll ──────────────────────────────────────────────────────────────────

vim.keymap.set({ 'n', 'v' }, '<C-f>', '20jzz', { noremap = true })
vim.keymap.set({ 'n', 'v' }, '<C-b>', '20kzz', { noremap = true })
vim.keymap.set('n', 'z', 'zz', { noremap = true })

-- ─── Standard conveniences ───────────────────────────────────────────────────

vim.keymap.set({ 'n', 'i', 'v' }, '<C-s>', smart_save,
  { noremap = true, silent = true, desc = 'Smart save' })
vim.keymap.set('v', '<C-c>', '"+y',
  { noremap = true, silent = true, desc = 'Copy to clipboard' })
vim.keymap.set('i', '<C-v>', '<C-r>+',
  { noremap = true, silent = true, desc = 'Paste from clipboard' })
vim.keymap.set('n', '<M-w>', toggle_wrap,
  { noremap = true, silent = true, desc = 'Toggle word wrap' })

-- ─── Comment toggle ──────────────────────────────────────────────────────────

vim.keymap.set('n', '<C-/>',  comment_toggle_line,   { noremap = true, silent = true })
vim.keymap.set('n', '<C-_>',  comment_toggle_line,   { noremap = true, silent = true })
vim.keymap.set('v', '<C-/>',  comment_toggle_visual, { noremap = true, silent = true })
vim.keymap.set('v', '<C-_>',  comment_toggle_visual, { noremap = true, silent = true })

-- ─── File operations ─────────────────────────────────────────────────────────

vim.keymap.set('n', '<leader>fr', rename_file,
  { noremap = true, silent = true, desc = 'Rename current file' })
vim.keymap.set('n', '<leader>fd', delete_file,
  { noremap = true, silent = true, desc = 'Delete current file' })

-- ─── LSP hover / diagnostic (Ctrl+M) ────────────────────────────────────────
--
-- Priority: diagnostics (errors/warnings) first, LSP hover as fallback.
-- NOTE: <C-m> = <CR> in most terminals.  If Enter breaks, rebind to <M-m>.

vim.keymap.set('n', '<C-m>', function()
  local lnum  = vim.api.nvim_win_get_cursor(0)[1] - 1
  local diags = vim.diagnostic.get(0, { lnum = lnum })
  if #diags > 0 then
    table.sort(diags, function(a, b) return a.severity < b.severity end)
    vim.diagnostic.open_float(nil, {
      scope = 'cursor', border = 'rounded', source = 'always',
      header = '', prefix = '',
    })
    return
  end
  local clients = (vim.lsp.get_clients or vim.lsp.get_active_clients)({ bufnr = 0 })
  for _, c in ipairs(clients) do
    if c.supports_method('textDocument/hover') then
      vim.lsp.buf.hover() ; return
    end
  end
end, { noremap = true, silent = true, desc = 'Diagnostic / hover info' })

-- Make all LSP floats non-focusable so the cursor can never get trapped.
local _orig_preview = vim.lsp.util.open_floating_preview
vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
  opts = opts or {} ; opts.focusable = false
  return _orig_preview(contents, syntax, opts, ...)
end

-- ─── Escape aliases — close floats + clear search highlights ─────────────────
--
-- close_floats() dismisses any open diagnostic/hover float windows so you
-- never need to move the cursor to get rid of them.

vim.keymap.set('n', '<Esc>', function()
  close_floats() ; vim.cmd('nohlsearch')
end, { noremap = true, silent = true })

vim.keymap.set('n', '<C-g>', function()
  close_floats() ; vim.cmd('nohlsearch')
end, { noremap = true, silent = true })

vim.keymap.set('n', '<C-[>', function()
  close_floats() ; vim.cmd('nohlsearch')
end, { noremap = true, silent = true })

vim.keymap.set({ 'i', 'v' }, '<C-g>', '<Esc><Cmd>nohlsearch<CR>',
  { noremap = true, silent = true })
vim.keymap.set({ 'i', 'v' }, '<C-[>', '<Esc><Cmd>nohlsearch<CR>',
  { noremap = true, silent = true })
vim.keymap.set('c', '<C-g>', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('c', '<C-[>', '<Esc>', { noremap = true, silent = true })
