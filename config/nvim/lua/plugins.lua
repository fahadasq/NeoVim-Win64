-- lua/plugins.lua

return {

  -- ─── Colorscheme ───────────────────────────────────────────────────────────
  {
    'folke/tokyonight.nvim',
    lazy     = false,
    priority = 1000,
    config   = function()
      vim.cmd([[colorscheme tokyonight]])
    end,
  },
  -- ─── Brace Highlights ──────────────────────────────────────────────────────
  {
      "lukas-reineke/indent-blankline.nvim",
      main = "ibl",
      ---@module "ibl"
      ---@type ibl.config
      opts = {},
  },

  -- ─── Telescope ─────────────────────────────────────────────────────────────
  {
    'nvim-telescope/telescope.nvim',
    event        = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-file-browser.nvim',
    },
    config = function()
      local actions = require('telescope.actions')

      require('telescope').setup({
        defaults = {
          mappings = {
            i = {
              ['<Esc>'] = actions.close,
              ['<C-g>'] = actions.close,
              -- <C-[> and <Esc> are the same byte (0x1B) in most terminals,
              -- but some terminal emulators (e.g. kitty, wezterm with full
              -- keyboard protocol) distinguish them.  Map both to be safe.
              ['<C-[>'] = actions.close,
              ['<C-c>'] = actions.close,
            },
            n = {
              ['<Esc>'] = actions.close,
              ['<C-g>'] = actions.close,
              ['<C-[>'] = actions.close,
            },
          },
          file_ignore_patterns = {
            'node_modules/',
            '%.git/',
            '%.lock$',
            '__pycache__/',
            '%.pyc$',
          },
        },
      })

      require('telescope').load_extension('file_browser')
    end,
  },

  -- ─── Comment toggling ──────────────────────────────────────────────────────
  {
    'numToStr/Comment.nvim',
    lazy   = false,
    config = function()
      require('Comment').setup({ mappings = { basic = false, extra = false } })
    end,
  },

  -- ─── Treesitter ────────────────────────────────────────────────────────────
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'master',
    build  = ':TSUpdate',
    lazy   = false,
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = {
          'lua', 'javascript', 'c', 'html', 'css', 'scss', 'typescript', 'svelte',
        },
        highlight = { enable = true, additional_vim_regex_highlighting = false },
        indent    = { enable = true },
      })
    end,
  },

  -- ─── LSP stack ─────────────────────────────────────────────────────────────
  { 'williamboman/mason.nvim' },
  { 'williamboman/mason-lspconfig.nvim' },
  { 'neovim/nvim-lspconfig' },

  -- ─── Completion ────────────────────────────────────────────────────────────
  { 'hrsh7th/nvim-cmp' },
  { 'hrsh7th/cmp-nvim-lsp' },
}
