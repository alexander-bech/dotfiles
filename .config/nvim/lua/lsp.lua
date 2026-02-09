-- ~/.config/nvim/lua/lsp.lua
-- No need for local lspconfig = require("lspconfig") anymore for this server,
-- but keep nvim-lspconfig installed in your plugins — it provides the default config files.

-- Configure zls (merges with lspconfig's defaults automatically if you don't override everything)
vim.lsp.config('zls', {
  cmd = { 'zls' },  -- assumes zls is in $PATH; change to full path if needed
  filetypes = { 'zig', 'zir' },
  root_dir = vim.fs.root(0, { 'build.zig', '.git' }) or vim.fn.getcwd(),
  single_file_support = true,
  -- Add any extra settings if you have them, e.g.:
  -- settings = { zls = { ... } },
})

-- Enable the server (this replaces the old .setup() call)
vim.lsp.enable('zls')

--vim.lsp.config('ty', {
--  settings = {
--    ty = {
--    }
--  }
--})
--

vim.lsp.config['ty'] = {
  -- Command and arguments to start the server.
  cmd = { 'ty', 'server' },
  -- Filetypes to automatically attach to.
  filetypes = { 'python' },
  -- Sets the "workspace" to the directory where any of these files is found.
  -- Files that share a root directory will reuse the LSP server connection.
  -- Nested lists indicate equal priority, see |vim.lsp.Config|.
  root_markers = { '.pyproject.toml', '.git' },
  -- Specific settings to send to the server. The schema is server-defined.
  -- Example: https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json
}

vim.lsp.enable('ty')

-- Your global keymaps on LspAttach (this part is fine, but consider moving it to an autocmd in after/plugin or init.lua if it's not server-specific)
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local opts = { buffer = args.buf }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)   -- Go to definition
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)   -- Go to references
    vim.keymap.set('n', 'K',  vim.lsp.buf.hover,       opts)   -- Hover info
    -- Add more LSP keymaps here if you want them everywhere, e.g.:
    -- vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    -- vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  end,
  -- Optional: only for zig/zir if you prefer server-specific maps
  -- pattern = { '*.zig', '*.zir' },
})
