-- lua/terminal.lua

local M = {}

M.term_buf          = nil
M.term_win          = nil
M.term_chan         = nil
M.last_editor_win   = nil
M.expanded          = false
M.SMALL_HEIGHT      = 6
M.LARGE_HEIGHT      = 0
M.project_find_opts = nil
M.project_dir       = nil

-- ─── Appearance ───────────────────────────────────────────────────────────────

local function define_highlights()
  vim.api.nvim_set_hl(0, 'TermPanelNormal', { bg = '#1e1e1e', fg = '#e0e2ea' })
end

local function style_term_win(win)
  vim.api.nvim_set_option_value('winhl',
    'Normal:TermPanelNormal,EndOfBuffer:TermPanelNormal', { win = win })
  vim.api.nvim_set_option_value('number',         false, { win = win })
  vim.api.nvim_set_option_value('relativenumber', false, { win = win })
  vim.api.nvim_set_option_value('signcolumn',     'no',  { win = win })
  vim.api.nvim_set_option_value('wrap',           false, { win = win })
end

-- ─── Scroll helpers ───────────────────────────────────────────────────────────

local function term_scroll_top()
  if M.term_win and vim.api.nvim_win_is_valid(M.term_win)
     and M.term_buf and vim.api.nvim_buf_is_valid(M.term_buf) then
    pcall(vim.api.nvim_win_set_cursor, M.term_win, { 1, 0 })
  end
end

local function term_scroll_bottom()
  if M.term_win and vim.api.nvim_win_is_valid(M.term_win)
     and M.term_buf and vim.api.nvim_buf_is_valid(M.term_buf) then
    local n = vim.api.nvim_buf_line_count(M.term_buf)
    pcall(vim.api.nvim_win_set_cursor, M.term_win, { n, 0 })
  end
end

-- ─── Send raw text to the shell ───────────────────────────────────────────────

local function term_send(text)
  if M.term_chan then
    vim.api.nvim_chan_send(M.term_chan, text)
  end
end

-- ─── Layout ───────────────────────────────────────────────────────────────────

function M.create_layout()
  define_highlights()
  local wins = vim.api.nvim_list_wins()
  if #wins < 2 then return end

  local left_win = nil
  for _, w in ipairs(wins) do
    if vim.api.nvim_win_get_position(w)[2] == 0 then
      left_win = w ; break
    end
  end
  if not left_win then left_win = wins[1] end

  local buf = vim.api.nvim_create_buf(false, false)
  M.term_buf = buf

  vim.api.nvim_set_current_win(left_win)
  vim.cmd('belowright ' .. M.SMALL_HEIGHT .. 'split')
  local tw = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(tw, buf)
  vim.api.nvim_win_set_height(tw, M.SMALL_HEIGHT)
  style_term_win(tw)
  M.term_win = tw

  M.term_chan = vim.fn.termopen(vim.o.shell, {
    cwd     = vim.fn.getcwd(),
    on_exit = function() M.term_chan = nil end,
  })

  vim.api.nvim_set_current_win(left_win)
  M.last_editor_win = left_win
end

-- ─── Project file ─────────────────────────────────────────────────────────────

local RESERVED = { F6 = true }

function M.load_project()
  local cwd  = vim.fn.getcwd()
  local path = vim.fn.fnamemodify(cwd .. '/.nvimproject', ':p')

  if vim.fn.filereadable(path) == 0 then
    vim.defer_fn(function()
      term_send('cd /d ' .. cwd .. ' && cls && @echo No .nvimproject found.\r')
      vim.defer_fn(term_scroll_top, 150)
    end, 300)
    return
  end

  local ok, project = pcall(dofile, path)
  if not ok then
    vim.notify('[terminal] .nvimproject error: ' .. tostring(project),
               vim.log.levels.ERROR)
    return
  end
  if type(project) ~= 'table' then
    vim.notify('[terminal] .nvimproject must return a table.', vim.log.levels.ERROR)
    return
  end

  M.project_dir = cwd

  local commands = project.commands
  if not commands then
    for k in pairs(project) do
      if type(k) == 'string' and k:match('^F%d+$') then
        commands = project ; break
      end
    end
  end

  if commands then
    local keys = {}
    for k in pairs(commands) do
      if type(k) == 'string' and k:match('^F%d+$') and not RESERVED[k] then
        table.insert(keys, k)
      end
    end

    for _, key in ipairs(keys) do
      local cmd  = commands[key]
      local proj = M.project_dir

      local function send_cmd()
        if not M.term_chan then
          vim.notify('[terminal] Shell is not running.', vim.log.levels.WARN)
          return
        end
        term_send('cls && @cd /d ' .. proj .. ' && ' .. cmd .. '\r')
        vim.defer_fn(term_scroll_bottom, 50)
      end

      local lhs = '<C-' .. key .. '>'
      vim.keymap.set({ 'n', 'v', 'i' }, lhs, send_cmd,
        { noremap = true, silent = true, desc = 'Project: ' .. cmd })
      vim.keymap.set('t', lhs, send_cmd,
        { noremap = true, silent = true, desc = 'Project: ' .. cmd })
    end
  end

  vim.keymap.set({ 'n', 'v', 'i', 't' }, '<C-F6>', function()
    term_send('\x03')
  end, { noremap = true, silent = true, desc = 'Interrupt (Ctrl+C)' })

  -- blacklist_patterns for telescope.
  if project.blacklist_patterns and #project.blacklist_patterns > 0 then
    local base = {}
    local ok2, tcfg = pcall(require, 'telescope.config')
    if ok2 then base = vim.deepcopy(tcfg.values.file_ignore_patterns or {}) end
    for _, p in ipairs(project.blacklist_patterns) do table.insert(base, p) end
    M.project_find_opts = { file_ignore_patterns = base }
  end

  -- Single-line banner: cls then one echo.  Uses the confirmed working pattern.
  vim.defer_fn(function()
    term_send('cd /d ' .. cwd .. ' && cls && @echo .nvimproject loaded.\r')
    vim.defer_fn(term_scroll_top, 150)
  end, 400)

  vim.notify('[terminal] .nvimproject loaded.', vim.log.levels.INFO)
end

-- ─── Focus toggle (Ctrl+T) ───────────────────────────────────────────────────

local function focus_toggle()
  if not (M.term_win and vim.api.nvim_win_is_valid(M.term_win)) then
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == M.term_buf then
        M.term_win = w ; break
      end
    end
  end
  if not M.term_win then return end
  local cur = vim.api.nvim_get_current_win()
  if cur == M.term_win then
    local target = M.last_editor_win
    if not (target and vim.api.nvim_win_is_valid(target)) then
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if w ~= M.term_win then target = w ; break end
      end
    end
    if target then vim.api.nvim_set_current_win(target) end
  else
    M.last_editor_win = cur
    vim.api.nvim_set_current_win(M.term_win)
    term_scroll_bottom()
    vim.cmd('startinsert')
  end
end

vim.keymap.set({ 'n', 'v', 'i' }, '<C-t>', focus_toggle,
  { noremap = true, silent = true, desc = 'Focus terminal panel' })
vim.keymap.set('t', '<C-t>', focus_toggle,
  { noremap = true, silent = true, desc = 'Focus terminal panel' })

-- ─── Height toggle (Home) ────────────────────────────────────────────────────

local function height_toggle()
  if not (M.term_win and vim.api.nvim_win_is_valid(M.term_win)) then
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == M.term_buf then
        M.term_win = w ; break
      end
    end
  end
  if not M.term_win then return end
  M.LARGE_HEIGHT = math.floor(vim.o.lines * 0.5)
  if M.expanded then
    vim.api.nvim_win_set_height(M.term_win, M.SMALL_HEIGHT)
    M.expanded = false
  else
    vim.api.nvim_win_set_height(M.term_win, M.LARGE_HEIGHT)
    M.expanded = true
  end
  vim.defer_fn(term_scroll_bottom, 30)
end

vim.keymap.set({ 'n', 'v' }, '<Home>', height_toggle,
  { noremap = true, silent = true, desc = 'Toggle terminal panel height' })
vim.keymap.set('t', '<Home>', height_toggle,
  { noremap = true, silent = true, desc = 'Toggle terminal panel height' })

-- ─── Ctrl+, cycles editor windows only ───────────────────────────────────────

local function cycle_editors()
  if not (M.term_win and vim.api.nvim_win_is_valid(M.term_win)) then
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == M.term_buf then
        M.term_win = w ; break
      end
    end
  end
  local cur     = vim.api.nvim_get_current_win()
  local editors = {}
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if w ~= M.term_win then table.insert(editors, w) end
  end
  if #editors < 2 then return end
  for i, w in ipairs(editors) do
    if w == cur then
      local next = editors[(i % #editors) + 1]
      M.last_editor_win = next
      vim.api.nvim_set_current_win(next)
      return
    end
  end
  M.last_editor_win = editors[1]
  vim.api.nvim_set_current_win(editors[1])
end

vim.keymap.set({ 'n', 'v', 'i' }, '<C-,>', cycle_editors,
  { noremap = true, silent = true, desc = 'Cycle editor panels' })
vim.keymap.set('t', '<C-,>', cycle_editors,
  { noremap = true, silent = true, desc = 'Cycle editor panels' })

-- ─── Focus + expand toggle (Ctrl+Shift+T) ────────────────────────────────────
--
-- Focused on terminal  →  collapse + move focus to editor
-- Focused on editor    →  expand terminal + move focus to terminal

local function focus_expand_toggle()
  if not (M.term_win and vim.api.nvim_win_is_valid(M.term_win)) then
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == M.term_buf then
        M.term_win = w ; break
      end
    end
  end
  if not M.term_win then return end

  local cur = vim.api.nvim_get_current_win()
  if cur == M.term_win then
    -- Collapse and return to editor.
    vim.api.nvim_win_set_height(M.term_win, M.SMALL_HEIGHT)
    M.expanded = false
    local target = M.last_editor_win
    if not (target and vim.api.nvim_win_is_valid(target)) then
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if w ~= M.term_win then target = w ; break end
      end
    end
    if target then vim.api.nvim_set_current_win(target) end
  else
    -- Expand and focus terminal.
    M.last_editor_win = cur
    M.LARGE_HEIGHT = math.floor(vim.o.lines * 0.5)
    if not M.expanded then
      vim.api.nvim_win_set_height(M.term_win, M.LARGE_HEIGHT)
      M.expanded = true
    end
    vim.api.nvim_set_current_win(M.term_win)
    term_scroll_bottom()
    vim.cmd('startinsert')
  end
end

vim.keymap.set({ 'n', 'v', 'i' }, '<C-S-t>', focus_expand_toggle,
  { noremap = true, silent = true, desc = 'Toggle terminal focus + expand' })
vim.keymap.set('t', '<C-S-t>', focus_expand_toggle,
  { noremap = true, silent = true, desc = 'Toggle terminal focus + expand' })

return M
