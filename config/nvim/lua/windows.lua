-- lua/windows.lua

local terminal = require('terminal')

-- ─── Startup layout ───────────────────────────────────────────────────────────

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    if #vim.api.nvim_list_wins() == 1 then
      vim.cmd('vsplit')
      vim.cmd('wincmd h')
    end
    terminal.create_layout()
    terminal.load_project()
  end,
})

-- ─── Kill buffer (Ctrl+K) ────────────────────────────────────────────────────

vim.keymap.set('n', '<C-k>', function()
  local buf = vim.api.nvim_get_current_buf()
  if buf == terminal.term_buf then return end
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  if #bufs > 1 then vim.cmd('bprevious') else vim.cmd('enew') end
  vim.api.nvim_buf_delete(buf, { force = false })
end, { noremap = true, silent = true, desc = 'Kill buffer' })

-- ─── Close window (Ctrl+Shift+K) ─────────────────────────────────────────────

vim.keymap.set('n', '<C-S-k>', function()
  local cur = vim.api.nvim_get_current_win()
  if cur == terminal.term_win then
    vim.notify('Cannot close the terminal panel. Use Alt+\\ to split above it.',
               vim.log.levels.INFO)
    return
  end
  if #vim.api.nvim_list_wins() <= 1 then
    vim.notify('Cannot close the last window.', vim.log.levels.WARN)
    return
  end
  vim.ui.input({ prompt = 'Close this window? [y/N]: ' }, function(answer)
    if answer and answer:lower() == 'y' then vim.cmd('close') end
  end)
end, { noremap = true, silent = true, desc = 'Close window (with confirmation)' })

-- ─── Vertical split (Ctrl+\) ─────────────────────────────────────────────────

vim.keymap.set('n', '<C-Bslash>', function()
  if vim.api.nvim_get_current_win() == terminal.term_win then
    vim.notify('Use Alt+\\ to split above the terminal panel.', vim.log.levels.INFO)
    return
  end
  vim.cmd('vsplit')
  vim.cmd('wincmd h')
end, { noremap = true, silent = true, desc = 'Split vertically' })

-- ─── Horizontal split / layout recovery (Alt+\) ──────────────────────────────
--
-- From the terminal panel: creates an editor window above, resets terminal
-- to compact height, and clears the inherited winhl so the new editor has
-- the normal background (not the darker terminal colour).
--
-- From any editor window: standard horizontal split.

local function clear_editor_win_style(win)
  -- Unset winhl so the window uses the global Normal highlight instead of
  -- TermPanelNormal which it may have inherited from the terminal window.
  vim.api.nvim_set_option_value('winhl',          '',     { win = win })
  vim.api.nvim_set_option_value('number',         true,   { win = win })
  vim.api.nvim_set_option_value('relativenumber', true,   { win = win })
  vim.api.nvim_set_option_value('signcolumn',     'yes',  { win = win })
  vim.api.nvim_set_option_value('wrap',           false,  { win = win })
  vim.api.nvim_set_option_value('cursorline',     false,  { win = win })
end

vim.keymap.set('n', '<M-Bslash>', function()
  local cur = vim.api.nvim_get_current_win()
  if cur == terminal.term_win then
    vim.cmd('aboveleft split')
    local new_win = vim.api.nvim_get_current_win()
    -- Reset terminal to compact height.
    if terminal.term_win and vim.api.nvim_win_is_valid(terminal.term_win) then
      vim.api.nvim_win_set_height(terminal.term_win, terminal.SMALL_HEIGHT)
    end
    terminal.expanded = false
    terminal.last_editor_win = new_win
    -- Replace terminal buffer if the new window inherited it.
    if vim.api.nvim_win_get_buf(new_win) == terminal.term_buf then
      vim.cmd('enew')
    end
    -- Clear terminal styling from the new editor window.
    clear_editor_win_style(new_win)
  else
    vim.cmd('split')
    -- Also clear styling on the resulting window just in case.
    clear_editor_win_style(vim.api.nvim_get_current_win())
  end
end, { noremap = true, silent = true, desc = 'Horizontal split / recover layout' })

-- ─── Reset layout (Ctrl+Shift+\) ─────────────────────────────────────────────
--
-- Closes all windows and recreates the default two-pane + terminal layout.

local function reset_layout()
  local cur_buf = vim.api.nvim_get_current_buf()

  if cur_buf == terminal.term_buf then
    cur_buf = nil
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) and b ~= terminal.term_buf
         and vim.bo[b].buflisted then
        cur_buf = b ; break
      end
    end
  end

  local keep = vim.api.nvim_get_current_win()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if w ~= keep then pcall(vim.api.nvim_win_close, w, true) end
  end

  if cur_buf and vim.api.nvim_buf_is_valid(cur_buf) then
    vim.api.nvim_win_set_buf(0, cur_buf)
  elseif vim.api.nvim_get_current_buf() == terminal.term_buf then
    vim.cmd('enew')
  end
  clear_editor_win_style(vim.api.nvim_get_current_win())

  vim.cmd('vsplit')
  vim.cmd('wincmd h')

  if terminal.term_buf and vim.api.nvim_buf_is_valid(terminal.term_buf) then
    vim.cmd('belowright ' .. terminal.SMALL_HEIGHT .. 'split')
    local tw = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(tw, terminal.term_buf)
    vim.api.nvim_win_set_height(tw, terminal.SMALL_HEIGHT)
    terminal.style_term_win(tw)
    terminal.term_win = tw
    terminal.expanded = false
    vim.cmd('wincmd k')
  end

  terminal.last_editor_win = vim.api.nvim_get_current_win()

  vim.cmd('wincmd =')
  if terminal.term_win and vim.api.nvim_win_is_valid(terminal.term_win) then
    vim.api.nvim_win_set_height(terminal.term_win, terminal.SMALL_HEIGHT)
  end
end

vim.keymap.set({ 'n', 'v', 'i' }, '<M-0>', reset_layout,
  { noremap = true, silent = true, desc = 'Reset to default layout' })
vim.keymap.set('t', '<M-0>', reset_layout,
  { noremap = true, silent = true, desc = 'Reset to default layout' })

-- ─── Goto definition ─────────────────────────────────────────────────────────
--
-- Some servers (e.g. ols on an `import` line, which can resolve to every
-- file in the imported package) report more than one location, which trips
-- Neovim's default "multiple results -> quickfix" behaviour. Mirror what
-- Ctrl+] does for multi-match tags: jump straight to the first match instead
-- of stopping on a list.

local function goto_definition_on_list(options)
  local item = options.items[1]
  if not item then return end
  vim.cmd('edit ' .. vim.fn.fnameescape(item.filename))
  vim.api.nvim_win_set_cursor(0, { item.lnum, item.col - 1 })
end

local function other_editor_win()
  local cur     = vim.api.nvim_get_current_win()
  local editors = {}
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if w ~= terminal.term_win then table.insert(editors, w) end
  end
  if #editors < 2 then return nil end
  for i, w in ipairs(editors) do
    if w == cur then return editors[(i % #editors) + 1] end
  end
end

vim.keymap.set('n', '<C-CR>', function()
  local buf    = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local target = other_editor_win()
  if target then
    vim.api.nvim_set_current_win(target)
  else
    vim.cmd('vsplit')
  end
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_cursor(0, cursor)
  vim.lsp.buf.definition({ on_list = goto_definition_on_list })
end, { noremap = true, silent = true, desc = 'Goto definition in other panel' })

vim.keymap.set('n', '<C-S-CR>', function()
  vim.lsp.buf.definition({ on_list = goto_definition_on_list })
end, { noremap = true, silent = true, desc = 'Goto definition in same panel' })
