-- lua/completion.lua
--
-- nvim-cmp configured for MANUAL trigger only — no popup while typing.
-- Press Ctrl+N to open suggestions, then navigate with Up/Down arrows.
--
-- Dependencies (already in plugins.lua):
--   'hrsh7th/nvim-cmp'
--   'hrsh7th/cmp-nvim-lsp'

local cmp = require('cmp')

cmp.setup({
  -- Disable automatic completion popup.
  -- The completion menu only appears when you explicitly press <C-n>.
  completion = {
    autocomplete = false,
  },

  mapping = cmp.mapping.preset.insert({
    -- Manually trigger the completion menu.
    ['<C-n>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'n' }),

    -- Navigate the suggestion list with arrow keys.
    ['<Down>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
    ['<Up>']   = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),

    -- Confirm selection with Enter.
    ['<CR>']  = cmp.mapping.confirm({ select = true }),

    -- Close the completion menu.
    ['<Esc>'] = cmp.mapping.abort(),
    ['<C-g>'] = cmp.mapping.abort(),
  }),

  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
  }),

  -- Don't preselect any item — user explicitly chooses.
  preselect = cmp.PreselectMode.None,

  -- Show a simple bordered window.
  window = {
    completion    = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },
})
