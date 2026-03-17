-- lua/terminal.lua

local M = {}

M.term_buf        = nil
M.term_win        = nil
M.last_editor_win = nil
M.expanded        = false
M.current_job_id  = nil
M.SMALL_HEIGHT    = 5
M.LARGE_HEIGHT    = 0
M.project_find_opts = nil

-- ─── Output buffer ────────────────────────────────────────────────────────────

local function ensure_buf()
  if M.term_buf and vim.api.nvim_buf_is_valid(M.term_buf) then
    return M.term_buf
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype',    'nofile', { buf = buf })
  vim.api.nvim_set_option_value('bufhidden',  'hide',   { buf = buf })
  vim.api.nvim_set_option_value('swapfile',   false,    { buf = buf })
  vim.api.nvim_set_option_value('modifiable', true,     { buf = buf })
  vim.api.nvim_buf_set_name(buf, 'TerminalOutput')
  M.term_buf = buf
  return buf
end

local function buf_append(lines)
  local buf = ensure_buf()
  vim.api.nvim_set_option_value('modifiable', true,  { buf = buf })
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
end

local function buf_clear()
  local buf = ensure_buf()
  vim.api.nvim_set_option_value('modifiable', true,  { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
end

local function scroll_to_bottom()
  local win = nil
  if M.term_win and vim.api.nvim_win_is_valid(M.term_win) then
    win = M.term_win
  else
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == M.term_buf then
        win = w ; M.term_win = w ; break
      end
    end
  end
  if win then
    local n = vim.api.nvim_buf_line_count(M.term_buf)
    vim.api.nvim_win_set_cursor(win, { math.max(1, n), 0 })
  end
end

-- ─── Appearance ───────────────────────────────────────────────────────────────

local function define_highlights()
  vim.api.nvim_set_hl(0, 'TermPanelNormal', { bg = '#11121a', fg = '#a9b1d6' })
end

local function style_term_win(win)
  vim.api.nvim_set_option_value('winhl',
    'Normal:TermPanelNormal,EndOfBuffer:TermPanelNormal', { win = win })
  vim.api.nvim_set_option_value('number',         false, { win = win })
  vim.api.nvim_set_option_value('relativenumber', false, { win = win })
  vim.api.nvim_set_option_value('signcolumn',     'no',  { win = win })
  vim.api.nvim_set_option_value('wrap',           true,  { win = win })
  vim.api.nvim_set_option_value('cursorline',     false, { win = win })
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
  vim.api.nvim_set_current_win(left_win)
  vim.cmd('belowright ' .. M.SMALL_HEIGHT .. 'split')
  local tw = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(tw, ensure_buf())
  vim.api.nvim_win_set_height(tw, M.SMALL_HEIGHT)
  style_term_win(tw)
  M.term_win = tw
  buf_append({ '  No commands run yet.',
               '  Load a .nvimproject and press F1–F12.' })
  vim.api.nvim_set_current_win(left_win)
  M.last_editor_win = left_win
end

-- ─── Job management ───────────────────────────────────────────────────────────

function M.kill_current_job()
  if M.current_job_id then
    vim.fn.jobstop(M.current_job_id)
    M.current_job_id = nil
    buf_append({ '', '! Killed by user.' })
    scroll_to_bottom()
    return true
  end
  return false
end

local function do_run(cmd)
  buf_clear()
  local header = '$ ' .. cmd
  buf_append({ header, string.rep('─', math.min(#header + 2, 80)), '' })
  M.current_job_id = vim.fn.jobstart(cmd, {
    cwd             = vim.fn.getcwd(),
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      if not data then return end
      local lines = {}
      for _, l in ipairs(data) do table.insert(lines, l) end
      if lines[#lines] == '' then table.remove(lines) end
      if #lines > 0 then buf_append(lines) ; scroll_to_bottom() end
    end,
    on_stderr = function(_, data)
      if not data then return end
      local lines = {}
      for _, l in ipairs(data) do
        table.insert(lines, l ~= '' and ('! ' .. l) or '')
      end
      if lines[#lines] == '' then table.remove(lines) end
      if #lines > 0 then buf_append(lines) ; scroll_to_bottom() end
    end,
    on_exit = function(_, code)
      M.current_job_id = nil
      buf_append({ '', code == 0
        and '  ✓ Exited successfully.'
        or  ('  ✗ Exited with code ' .. code .. '.') })
      scroll_to_bottom()
    end,
  })
end

function M.run_command(cmd)
  if M.current_job_id then
    vim.ui.input(
      { prompt = 'A command is still running. Kill it and run new command? [y/N]: ' },
      function(answer)
        if answer and answer:lower() == 'y' then
          M.kill_current_job() ; do_run(cmd)
        end
      end)
  else
    do_run(cmd)
  end
end

-- ─── Project file ─────────────────────────────────────────────────────────────
--
-- .nvimproject format:
--
--   return {
--     commands = {
--       F1 = "npm run build",
--       F2 = "npm test",
--     },
--     blacklist_patterns = {   -- Lua patterns merged into file_ignore_patterns
--       "dist/",
--       "%.min%.js$",
--     },
--   }

local RESERVED_KEYS = { F6 = true }

function M.load_project()
  local path = vim.fn.fnamemodify(vim.fn.getcwd() .. '/.nvimproject', ':p')
  if vim.fn.filereadable(path) == 0 then return end

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

  -- Backwards compat: top-level F-key table.
  local commands = project.commands
  if not commands then
    for k in pairs(project) do
      if type(k) == 'string' and k:match('^F%d+$') then
        commands = project ; break
      end
    end
  end

  local cmd_count = 0
  if commands then
    for key, cmd in pairs(commands) do
      if type(key) == 'string' and key:match('^F%d+$') then
        if RESERVED_KEYS[key] then
          vim.notify('[terminal] ' .. key .. ' is reserved.', vim.log.levels.WARN)
        else
          local c = cmd
          vim.keymap.set({ 'n', 'v', 'i' }, '<' .. key .. '>', function()
            M.run_command(c)
          end, { noremap = true, silent = true, desc = 'Project: ' .. c })
          cmd_count = cmd_count + 1
        end
      end
    end
  end

  -- blacklist_patterns: merge on top of the global file_ignore_patterns.
  if project.blacklist_patterns and #project.blacklist_patterns > 0 then
    local base = {}
    local ok2, tcfg = pcall(require, 'telescope.config')
    if ok2 then
      base = vim.deepcopy(tcfg.values.file_ignore_patterns or {})
    end
    for _, p in ipairs(project.blacklist_patterns) do
      table.insert(base, p)
    end
    M.project_find_opts = { file_ignore_patterns = base }
  end

  local parts = { '[terminal] .nvimproject loaded' }
  if cmd_count > 0       then table.insert(parts, cmd_count .. ' command(s)') end
  if M.project_find_opts then table.insert(parts, 'blacklist active') end
  vim.notify(table.concat(parts, ', ') .. '.', vim.log.levels.INFO)
end

-- ─── F6 ───────────────────────────────────────────────────────────────────────

vim.keymap.set({ 'n', 'v', 'i' }, '<F6>', function()
  if not M.kill_current_job() then
    vim.notify('[terminal] No command is running.', vim.log.levels.INFO)
  end
end, { noremap = true, silent = true, desc = 'Kill running command' })

-- ─── Focus toggle (Ctrl+T) ───────────────────────────────────────────────────

vim.keymap.set({ 'n', 'v', 'i' }, '<C-t>', function()
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
  end
end, { noremap = true, silent = true, desc = 'Focus terminal panel' })

-- ─── Height toggle (Home) ────────────────────────────────────────────────────

vim.keymap.set({ 'n', 'v' }, '<Home>', function()
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
end, { noremap = true, silent = true, desc = 'Toggle terminal panel height' })

-- ─── Ctrl+, cycles editor windows only ───────────────────────────────────────

vim.keymap.set({ 'n', 'v', 'i' }, '<C-,>', function()
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
end, { noremap = true, silent = true, desc = 'Cycle editor panels' })

return M
