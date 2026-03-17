-- lua/telescope_bindings.lua

-- ─── Helper: open file browser at a given path ───────────────────────────────

local function open_browser(path)
  require('telescope').extensions.file_browser.file_browser({
    path              = path,
    hidden            = { file_browser = true, folder_browser = true },
    respect_gitignore = false,
    display_stat      = false,
    attach_mappings   = function(prompt_bufnr, map)
      local function drive_switch()
        local actions = require('telescope.actions')
        actions.close(prompt_bufnr)
        vim.ui.input(
          { prompt = 'Go to path/drive (e.g. D:\\ or E:\\projects): ' },
          function(input)
            if not input or input == '' then return end
            local target = input:gsub('\\', '/'):gsub('/+', '/')
            -- Keep trailing slash only for bare drive roots like "C:/"
            if not target:match('^%a:/$') then
              target = target:gsub('/$', '')
            end
            if vim.fn.isdirectory(target) == 0 then
              vim.notify('Not a directory: ' .. target, vim.log.levels.WARN)
              return
            end
            vim.schedule(function() open_browser(target) end)
          end
        )
      end

      -- Map in both insert and normal mode so it works regardless of which
      -- mode the browser opens in.
      map('i', '<C-r>', drive_switch)
      map('n', '<C-r>', drive_switch)
      return true
    end,
  })
end

-- ─── Ctrl+Shift+I  →  find files ─────────────────────────────────────────────

vim.keymap.set('', '<C-S-i>', function()
  local terminal = require('terminal')
  if terminal.project_find_opts then
    require('telescope.builtin').find_files(
      vim.deepcopy(terminal.project_find_opts)
    )
  else
    require('telescope.builtin').find_files()
  end
end, { noremap = true, desc = 'Find file' })

-- ─── Ctrl+I  →  browse open buffers ──────────────────────────────────────────

vim.keymap.set('', '<C-i>', function()
  require('telescope.builtin').buffers({
    sort_mru              = true,
    ignore_current_buffer = true,
  })
end, { noremap = true, desc = 'Browse open buffers' })

-- ─── Alt+F  →  live grep ──────────────────────────────────────────────────────

vim.keymap.set('', '<M-f>', function()
  require('telescope.builtin').live_grep()
end, { noremap = true, desc = 'Live grep' })

-- ─── Ctrl+Shift+F  →  file browser ───────────────────────────────────────────
--
-- Opens at the directory of the current file (or CWD if no file is open).
-- Hidden files shown.  .gitignore/.ignore not respected.
-- Press Ctrl+R inside the browser to jump to a different path or drive.

vim.keymap.set('', '<C-S-f>', function()
  local start_path = vim.fn.expand('%:p:h')
  if start_path == '' then start_path = vim.fn.getcwd() end
  open_browser(start_path)
end, { noremap = true, desc = 'File browser' })
