-- lua/lsp.lua

require('mason').setup({
    ui = {
        icons = {
            package_installed   = '✓',
            package_pending     = '➜',
            package_uninstalled = '✗',
        },
    },
})

local servers = {
    ts_ls         = {},
    eslint        = {},
    cssls         = {},
    html          = {},
    pyright       = {},
    clangd        = {},
    gopls         = {},
    ols           = {
        init_options = {
            collections = {
                { name = "core",   path = "C:\\Odin\\core" },
                { name = "vendor", path = "C:\\Odin\\vendor" },
                { name = "base",   path = "C:\\Odin\\base" },
            },
            formatter_type = "indent_tabs",
        },
    },
    lua_ls        = {
        settings = {
            Lua = {
                runtime     = { version = 'LuaJIT' },
                workspace   = {
                    checkThirdParty = false,
                    library = vim.api.nvim_get_runtime_file('', true),
                },
                diagnostics = { globals = { 'vim' } },
                telemetry   = { enable = false },
            },
        },
    },
}

local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok_cmp, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
if ok_cmp then
    capabilities = cmp_lsp.default_capabilities(capabilities)
end

local function on_attach(client, bufnr)
    local function map(lhs, rhs, desc)
        vim.keymap.set('n', lhs, rhs,
            { noremap = true, silent = true, buffer = bufnr, desc = desc })
    end

    map('gd',         vim.lsp.buf.definition,      'Goto definition')
    map('gD',         vim.lsp.buf.declaration,     'Goto declaration')
    map('gi',         vim.lsp.buf.implementation,  'Goto implementation')
    map('gr',         vim.lsp.buf.references,      'Find references')
    map('gt',         vim.lsp.buf.type_definition, 'Goto type definition')
    map('<C-p>',      vim.lsp.buf.signature_help,  'Signature help')
    map('<leader>ca', vim.lsp.buf.code_action,     'Code action')
    map('[d',         vim.diagnostic.goto_prev,    'Previous diagnostic')
    map(']d',         vim.diagnostic.goto_next,    'Next diagnostic')

    if client.supports_method('textDocument/formatting') then
        map('<leader>f', function()
            vim.lsp.buf.format({ async = true })
        end, 'Format buffer')
    end

    -- Show the active parameter list in a floating window as you type
    -- (no virtual text hint, to match the no-inline-clutter diagnostic style).
    require('lsp_signature').on_attach({
        bind             = true,
        hint_enable      = false,
        floating_window  = true,
        close_timeout    = 4000,
        max_height       = 8,
        max_width        = 60,
        handler_opts     = { border = 'rounded' },
    }, bufnr)
end

require('mason-lspconfig').setup({
    ensure_installed = vim.tbl_keys(servers),
})

-- Set up every server directly with vim.lsp.config()/vim.lsp.enable()
-- (the require('lspconfig')[name].setup() "framework" is deprecated on
-- Nvim 0.11+ and, on top of that, did not reliably call on_attach for
-- every installed server here, e.g. ols) — this guarantees on_attach
-- always runs for every server.
for server_name, server_config in pairs(servers) do
    local config        = vim.deepcopy(server_config)
    config.on_attach    = on_attach
    config.capabilities = capabilities
    vim.lsp.config(server_name, config)
    vim.lsp.enable(server_name)
end

-- ─── Diagnostic display ──────────────────────────────────────────────────────
--
-- No virtual text (the inline messages at end of line that go off-screen).
-- No gutter signs.
-- Coloured underlines only: yellow for warnings, red for errors.
-- Full message shown in a float when you press <C-m> (see keymaps.lua).

vim.diagnostic.config({
    virtual_text     = false,   -- disable end-of-line inline messages
    signs            = false,   -- disable gutter W / E symbols
    underline        = true,    -- coloured underline at the problem site
    update_in_insert = false,
    severity_sort    = true,
    float = {
        border = 'rounded',
        source = 'always',
        header = '',
        prefix = '',
    },
})
