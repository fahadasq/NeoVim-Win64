-- lua/claude_panel.lua
--
-- The Claude Code panel: a full-height terminal column on the right running
-- the `claude` CLI.  claudecode.nvim (plugins.lua) drives it through the
-- custom terminal provider exported as M.provider, so the plugin never opens
-- windows of its own and snacks.nvim is not needed.
--
-- Behaves like the shell panel in terminal.lua: unlisted buffer, same panel
-- styling, closing the window only hides it (the process keeps running), and
-- the window / process are rebuilt on demand.  Keybindings live in windows.lua.

local terminal = require('terminal')

local M = {}

M.buf  = nil
M.win  = nil
M.chan = nil

-- The plugin's terminal config (split_width_percentage, auto_insert, ...),
-- replaced by provider.setup().
local cfg = { split_width_percentage = 0.30, auto_insert = true }

-- ─── State helpers ────────────────────────────────────────────────────────────

local function is_float(win)
  return vim.api.nvim_win_get_config(win).relative ~= ''
end

local function buf_valid()
  return M.buf ~= nil and vim.api.nvim_buf_is_valid(M.buf)
end

local function alive()
  return M.chan ~= nil and buf_valid()
end

function M.is_buf(buf)
  return M.buf ~= nil and buf == M.buf
end

function M.is_win(win)
  return win ~= nil and buf_valid() and vim.api.nvim_win_is_valid(win)
     and vim.api.nvim_win_get_buf(win) == M.buf
end

-- An ordinary editor window: not a float, the shell panel or this panel.
local function is_editor(win)
  return win ~= nil and win ~= 0 and vim.api.nvim_win_is_valid(win)
     and not is_float(win) and not M.is_win(win)
     and vim.api.nvim_win_get_buf(win) ~= terminal.term_buf
end

-- Refresh M.win: the window currently showing M.buf, or nil.
local function find_win()
  if M.is_win(M.win) and not is_float(M.win) then return M.win end
  M.win = nil
  if not buf_valid() then return nil end
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if not is_float(w) and vim.api.nvim_win_get_buf(w) == M.buf then
      M.win = w ; break
    end
  end
  return M.win
end

function M.is_visible()
  return find_win() ~= nil
end

local function width()
  return math.floor(vim.o.columns * (cfg.split_width_percentage or 0.30))
end

-- ─── Window ───────────────────────────────────────────────────────────────────

-- Same look as the shell panel; 'winfixwidth' keeps the `wincmd =` in Alt+3,
-- font resizing and Claude's diffs from squeezing the column.
local function style_win(win)
  terminal.style_term_win(win)
  vim.api.nvim_set_option_value('winfixwidth', true, { win = win })
end

-- Split a full-height column off the right edge of the screen.  Focus is
-- left unchanged.  The caller puts a buffer in it and styles it.
local function open_win()
  local prev = vim.api.nvim_get_current_win()
  if is_float(prev) then
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if not is_float(w) then vim.api.nvim_set_current_win(w) ; break end
    end
  end
  vim.cmd('botright ' .. width() .. 'vsplit')
  local win = vim.api.nvim_get_current_win()
  -- A sized split takes all its columns from the right-most editor; share
  -- the rest out evenly again.  Widths only, so the shell keeps its height.
  vim.api.nvim_set_option_value('winfixwidth', true, { win = win })
  vim.cmd('horizontal wincmd =')
  if vim.api.nvim_win_is_valid(prev) then vim.api.nvim_set_current_win(prev) end
  M.win = win
  return win
end

-- ─── Process ──────────────────────────────────────────────────────────────────

-- The plugin's command line as termopen() arguments.  A list runs the exe
-- directly; an npm-style `claude.cmd` shim has to go through the shell.
local function claude_command(cmd)
  local ok, utils = pcall(require, 'claudecode.utils')
  local argv = ok and utils.parse_command(cmd)
                  or vim.split(cmd, '%s+', { trimempty = true })
  local exe = vim.fn.exepath(argv[1] or ''):lower()
  if exe:match('%.cmd$') or exe:match('%.bat$') then return cmd end
  return argv
end

-- Variables describing the terminal Neovide was started from (Windows
-- Terminal, VS Code, ...).  They are wrong inside Neovim's own terminal: with
-- WT_SESSION set, claude assumes Windows Terminal's keyboard encoding and no
-- longer understands Esc, Alt+<key> or Shift+Tab as Neovim sends them.
local OUTER_TERMINAL_VARS = {
  WT_SESSION = true, WT_PROFILE_ID = true,
  TERM_PROGRAM = true, TERM_PROGRAM_VERSION = true,
}

-- Neovim's environment minus the outer-terminal variables, plus `extra`
-- (the plugin's CLAUDE_CODE_SSE_PORT etc.).  Used with clear_env, since a
-- variable can't be unset through a merged `env`.
local function job_env(extra)
  local e = {}
  for k, v in pairs(vim.fn.environ()) do
    if not OUTER_TERMINAL_VARS[k:upper()] then e[k] = v end
  end
  for k, v in pairs(extra or {}) do e[k] = v end
  return e
end

-- Buffer-local behaviour of the Claude buffer.
local function setup_buf(buf)
  -- Entered from an editor however it happened (Alt+C, a mouse click, ...):
  -- that editor is where Alt+C / Ctrl+T go back to.
  vim.api.nvim_create_autocmd('WinEnter', {
    buffer   = buf,
    callback = function()
      local prev = vim.fn.win_getid(vim.fn.winnr('#'))
      if is_editor(prev) then terminal.last_editor_win = prev end
    end,
  })

  -- Entering the panel (Ctrl+T back from the shell, a mouse click, ...)
  -- lands in Terminal mode, ready to type -- the plugin's `auto_insert`.
  vim.api.nvim_create_autocmd('BufEnter', {
    buffer   = buf,
    callback = function()
      vim.schedule(function()
        if cfg.auto_insert ~= false and M.chan and M.buf == buf
           and vim.api.nvim_get_current_buf() == buf
           and vim.api.nvim_get_mode().mode == 'n' then
          vim.cmd('startinsert')
        end
      end)
    end,
  })

  -- Neovide has no Terminal-mode paste key.  (Claude's own Alt+V pastes an
  -- image.)
  vim.keymap.set('t', '<C-S-v>', function()
    vim.api.nvim_paste(vim.fn.getreg('+'), true, -1)
  end, { buffer = buf, noremap = true, silent = true, desc = 'Paste clipboard into Claude' })

  -- Neovim's terminal sends Shift+Enter as a plain Enter, which submits the
  -- prompt.  Make it Claude's newline key (Ctrl+J), as in Windows Terminal.
  vim.keymap.set('t', '<S-CR>', '<C-j>',
    { buffer = buf, noremap = true, silent = true, desc = 'Newline in Claude prompt' })

  -- A mouse-wheel scroll or a click drops the panel into Normal mode, where
  -- Claude's keys would do nothing (or, for Ctrl+J / Ctrl+O, jump the window
  -- to another file).  In this buffer they go back to Claude instead.
  local function to_claude(lhs, keys)
    vim.keymap.set('n', lhs, 'i' .. keys,
      { buffer = buf, noremap = true, silent = true, desc = 'Back to Claude: ' .. keys })
  end
  to_claude('<CR>',    '<CR>')
  to_claude('<S-CR>',  '<C-j>')
  for _, k in ipairs({ '<C-j>', '<S-Tab>', '<M-p>', '<M-v>', '<C-r>', '<C-o>' }) do
    to_claude(k, k)
  end
  vim.keymap.set('n', '<C-S-v>',
    'i<Cmd>lua vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)<CR>',
    { buffer = buf, noremap = true, silent = true, desc = 'Paste clipboard into Claude' })
  -- A plain click means "type here" (a drag still selects text to copy).
  vim.keymap.set('n', '<LeftRelease>', '<LeftRelease><Cmd>startinsert<CR>',
    { buffer = buf, noremap = true, silent = true, desc = 'Click: back to typing in Claude' })
end

-- Start a fresh `claude` in a new buffer shown in `win`.
-- Returns ok, buf (the new buffer, valid even on failure so the caller can
-- clean it up).
local function start(win, cmd, env, ecfg)
  local buf = vim.api.nvim_create_buf(false, false)
  vim.b[buf].claude_panel = true
  vim.api.nvim_win_set_buf(win, buf)

  local ok, chan
  vim.api.nvim_win_call(win, function()
    ok, chan = pcall(vim.fn.termopen, claude_command(cmd), {
      env       = job_env(env),
      clear_env = true,
      cwd     = (ecfg and ecfg.cwd) or vim.fn.getcwd(),
      -- Only clear state for this job; an older session may exit after a restart.
      on_exit = function(job) if M.chan == job then M.chan = nil end end,
    })
  end)
  if not ok or type(chan) ~= 'number' or chan <= 0 then
    vim.notify('[claude] Could not start `' .. cmd .. '`: '
               .. (ok and 'termopen failed' or tostring(chan)), vim.log.levels.ERROR)
    return false, buf
  end

  vim.bo[buf].bufhidden = 'hide'
  -- termopen() fires TermOpen, whose colorscheme handler overwrites
  -- 'winhighlight' -- style afterwards (as terminal.lua does).
  style_win(win)
  setup_buf(buf)
  M.buf, M.chan = buf, chan
  return true, buf
end

-- Make sure the panel is visible and Claude is running, rebuilding the
-- window and/or restarting Claude as needed.
-- Returns ok, recovered (true if anything had to be rebuilt).
local function ensure(cmd, env, ecfg)
  local win = find_win()
  if win and alive() then return true, false end

  local created = false
  if not win then win = open_win() ; created = true end

  if alive() then
    vim.api.nvim_win_set_buf(win, M.buf)
    style_win(win)
    return true, true
  end

  local old = M.buf
  local ok, buf = start(win, cmd, env, ecfg)
  if not ok then
    if created then
      pcall(vim.api.nvim_win_close, win, true)
    elseif old and vim.api.nvim_buf_is_valid(old) then
      vim.api.nvim_win_set_buf(win, old)
      style_win(win)
    end
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return false, false
  end
  if old and old ~= M.buf and vim.api.nvim_buf_is_valid(old) then
    pcall(vim.api.nvim_buf_delete, old, { force = true })
  end
  return true, true
end

-- ─── Focus ────────────────────────────────────────────────────────────────────

local function usable(w)
  return w ~= nil and vim.api.nvim_win_is_valid(w)
     and not is_float(w) and not M.is_win(w)
end

-- Move into the panel.  Coming from an editor makes it the one to go back to.
local function enter(win)
  local cur = vim.api.nvim_get_current_win()
  if cur ~= win then
    if is_editor(cur) then terminal.last_editor_win = cur end
    vim.api.nvim_set_current_win(win)
  end
  if cfg.auto_insert ~= false and alive() then vim.cmd('startinsert') end
end

-- Leave the panel for the last editor (like Ctrl+T from the shell), never the
-- shell unless there is no editor at all -- otherwise Alt+C from the shell
-- and back would ping-pong between the two terminals.  Returns false if there
-- is nowhere to go.
local function go_back()
  local target = terminal.last_editor_win
  if not is_editor(target) then
    target = nil
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if is_editor(w) then target = w ; break end
    end
  end
  if not target then
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if usable(w) then target = w ; break end
    end
  end
  if not target then return false end

  vim.api.nvim_set_current_win(target)
  if vim.api.nvim_win_get_buf(target) == terminal.term_buf then
    vim.cmd('startinsert')
  end
  return true
end

-- ─── Public panel API (used by windows.lua) ───────────────────────────────────

-- Close the panel window only; Claude keeps running in the hidden buffer.
function M.hide()
  local win = find_win()
  if not win then return end
  if vim.api.nvim_get_current_win() == win then go_back() end
  if not pcall(vim.api.nvim_win_close, win, false) then
    vim.notify('Cannot hide the Claude panel: it is the last window.', vim.log.levels.INFO)
  end
end

-- Put a hidden panel back on the right without moving focus (layout presets).
function M.reattach()
  if not buf_valid() or find_win() then return end
  local win = open_win()
  vim.api.nvim_win_set_buf(win, M.buf)
  style_win(win)
end

-- Alt+Shift+C: show / hide without moving focus.  Showing goes through the
-- plugin so a first start gets its command line and environment.
function M.toggle_visible()
  if M.is_visible() then
    M.hide()
  else
    require('claudecode.terminal').ensure_visible()
  end
end

-- Alt+C: editor <-> Claude.
function M.focus_toggle()
  require('claudecode.terminal').focus_toggle()
end

-- ─── claudecode.nvim terminal provider ────────────────────────────────────────

-- Stop Claude and remove its buffer (:ClaudeCodeClose -- the only path that
-- ends the session).
local function close()
  if not buf_valid() then return end
  if M.is_win(vim.api.nvim_get_current_win()) then go_back() end
  local buf, chan = M.buf, M.chan
  M.buf, M.chan, M.win = nil, nil, nil
  if chan then
    -- Deleting a terminal buffer while a write to its job is pending can hang
    -- Neovim (neovim#42508), so wait for the job to exit first.
    local exited = false
    vim.api.nvim_create_autocmd('TermClose', {
      buffer = buf, once = true, callback = function() exited = true end,
    })
    if vim.fn.jobstop(chan) == 1 then
      vim.wait(1000, function()
        return exited or not vim.api.nvim_buf_is_valid(buf)
      end, 10)
    end
  end
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

M.provider = {
  setup = function(c) if type(c) == 'table' then cfg = c end end,

  is_available = function() return true end,

  -- A finished session counts as none, so the next open starts a new one.
  get_active_bufnr = function() return alive() and M.buf or nil end,

  open = function(cmd, env, ecfg, focus)
    if ensure(cmd, env, ecfg) and focus ~= false then enter(M.win) end
  end,

  close = close,

  -- :ClaudeCode -- hide if visible, otherwise show + focus.
  simple_toggle = function(cmd, env, ecfg)
    if M.is_visible() then M.hide() ; return end
    if ensure(cmd, env, ecfg) then enter(M.win) end
  end,

  -- :ClaudeCodeFocus / Alt+C -- like Ctrl+T for the shell: from the panel go
  -- back, from anywhere else focus it (rebuilding / restarting as needed).
  focus_toggle = function(cmd, env, ecfg)
    local cur = vim.api.nvim_get_current_win()
    local ok, recovered = ensure(cmd, env, ecfg)
    if not ok then return end
    if M.is_win(cur) and not recovered then go_back() else enter(M.win) end
  end,
}

-- ─── Autocmds ─────────────────────────────────────────────────────────────────

local group = vim.api.nvim_create_augroup('ClaudePanel', { clear = true })

-- Font size changes and Neovide window resizes: keep the column at its
-- configured share of the screen.
vim.api.nvim_create_autocmd('VimResized', {
  group    = group,
  callback = function()
    local win = find_win()
    if win then pcall(vim.api.nvim_win_set_width, win, width()) end
  end,
})

-- ─── Diffs ────────────────────────────────────────────────────────────────────
--
-- The plugin's inline diff (diff_opts.layout = 'unified') opens in a new split
-- beside the first editor.  With two or more editors open that's one panel
-- too many, so the diff borrows one of them instead: the editor already
-- showing the file, otherwise one you weren't working in.  The file it showed
-- comes back when the diff closes.
--
-- The plugin's cleanup closes the diff window and deletes the diff buffer,
-- and deleting a buffer closes every window showing it (the borrowed editor),
-- so both are taken out of its diff state and handled here instead.

local borrowed = {}   -- tab_name -> { win, buf, orig_buf, view, signcolumn }

local function same_file(a, b)
  local function norm(p)
    p = vim.fs.normalize(vim.fn.fnamemodify(p, ':p'))
    return vim.fn.has('win32') == 1 and p:lower() or p
  end
  return a ~= '' and b ~= '' and norm(a) == norm(b)
end

local function pick_host(state, dwin)
  local editors = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(dwin))) do
    if w ~= dwin and is_editor(w) and not vim.wo[w].diff and not vim.wo[w].previewwindow then
      editors[#editors + 1] = w
    end
  end
  if #editors < 2 then return nil end
  for _, w in ipairs(editors) do
    if same_file(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)), state.old_file_path) then
      return w
    end
  end
  local working = terminal.last_editor_win
  if state.target_window ~= working and vim.tbl_contains(editors, state.target_window) then
    return state.target_window
  end
  for _, w in ipairs(editors) do
    if w ~= working then return w end
  end
end

local function borrow(diff, tab_name, state)
  if state.layout ~= 'unified' or state.created_new_tab then return end
  local dwin, buf = state.new_window, state.new_buffer
  if not (dwin and vim.api.nvim_win_is_valid(dwin) and buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local host = pick_host(state, dwin)
  if not host then return end

  local rec = {
    win        = host,
    buf        = buf,
    orig_buf   = vim.api.nvim_win_get_buf(host),
    view       = vim.api.nvim_win_call(host, vim.fn.winsaveview),
    signcolumn = vim.api.nvim_get_option_value('signcolumn', { win = host, scope = 'local' }),
  }
  local cursor  = vim.api.nvim_win_get_cursor(dwin)
  local focused = vim.api.nvim_get_current_win() == dwin
  -- The plugin filled the buffer without clearing 'modified', and Neovim
  -- won't take a modified 'bufhidden=wipe' buffer out of a window (E37), so
  -- your file couldn't come back (nor Ctrl+I away from the proposal).
  -- Nothing is lost: accepting goes through the plugin's write handler.
  vim.bo[buf].modified = false
  if not pcall(vim.api.nvim_win_set_buf, host, buf) then return end
  vim.api.nvim_set_option_value('signcolumn', 'yes', { win = host, scope = 'local' })
  pcall(vim.api.nvim_win_set_cursor, host, cursor)
  if focused then vim.api.nvim_set_current_win(host) end
  vim.api.nvim_win_close(dwin, true)   -- buffer stays: the host still shows it

  state.new_window, state.new_buffer = nil, nil
  borrowed[tab_name] = rec
  -- The split's `wincmd =` resized everything; the layout is back to what
  -- the plugin saved before the diff, so give every window its size back.
  if state.window_sizes then pcall(diff._restore_window_sizes, state.window_sizes) end
end

local function give_back(tab_name)
  local rec = borrowed[tab_name]
  if not rec then return end
  borrowed[tab_name] = nil
  local w = rec.win
  -- Leave the window alone if you already switched it to another buffer.
  if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == rec.buf then
    if vim.api.nvim_buf_is_valid(rec.orig_buf) then
      vim.api.nvim_win_set_buf(w, rec.orig_buf)
      -- Neovim remembers this window's cursor and scroll for the buffer and
      -- restores them itself.  (rec.view can be stale on scroll: it was read
      -- right after the plugin split and resized the window.)  Use it only
      -- if the cursor didn't come back.
      if vim.api.nvim_win_get_cursor(w)[1] ~= rec.view.lnum then
        vim.api.nvim_win_call(w, function() vim.fn.winrestview(rec.view) end)
      end
    else
      vim.api.nvim_win_call(w, function() vim.cmd('enew') end)
    end
    vim.api.nvim_set_option_value('signcolumn', rec.signcolumn, { win = w, scope = 'local' })
  end
  if vim.api.nvim_buf_is_valid(rec.buf) then
    pcall(vim.api.nvim_buf_delete, rec.buf, { force = true })
  end
end

-- True for an editor window currently lent to a Claude diff (windows.lua's
-- Ctrl+Shift+K rejects the diff there instead of closing your window).
function M.is_diff_host(win)
  for _, rec in pairs(borrowed) do
    if rec.win == win and vim.api.nvim_win_is_valid(win)
       and vim.api.nvim_win_get_buf(win) == rec.buf then
      return true
    end
  end
  return false
end

-- Esc / Ctrl+G / Ctrl+[ in the proposal reject it.  Like the global versions
-- (keymaps.lua) they first dismiss an open popup, if there is one.
local function map_reject_keys(buf)
  local function reject()
    local had_float = false
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if is_float(w) then had_float = true ; pcall(vim.api.nvim_win_close, w, false) end
    end
    if had_float then return end
    vim.cmd('ClaudeCodeDiffDeny')
  end
  for _, lhs in ipairs({ '<Esc>', '<C-g>', '<C-[>' }) do
    vim.keymap.set('n', lhs, reject,
      { buffer = buf, nowait = true, silent = true, desc = 'Claude: reject diff' })
  end
end

vim.api.nvim_create_autocmd('User', {
  group    = group,
  pattern  = 'ClaudeCodeDiffOpened',
  callback = function(args)
    local data = args.data or {}
    local dwin = data.diff_window
    if dwin and vim.api.nvim_win_is_valid(dwin) then
      map_reject_keys(vim.api.nvim_win_get_buf(dwin))
    end
    local ok, diff = pcall(require, 'claudecode.diff')
    local state = ok and diff._get_active_diffs and diff._get_active_diffs()[data.tab_name]
    if state then
      local bok, err = pcall(borrow, diff, data.tab_name, state)
      if not bok then vim.notify('Claude diff: ' .. tostring(err), vim.log.levels.WARN) end
    end
    -- A diff's `wincmd =` stretches the shell panel; put it back.  (The
    -- plugin restores every window's size itself when the diff closes.)
    terminal.set_height(terminal.expanded and math.floor(vim.o.lines * 0.5)
                        or terminal.SMALL_HEIGHT)
  end,
})

vim.api.nvim_create_autocmd('User', {
  group    = group,
  pattern  = 'ClaudeCodeDiffClosed',
  callback = function(args)
    give_back((args.data or {}).tab_name)
  end,
})

return M
