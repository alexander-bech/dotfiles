vim.opt.clipboard = "unnamedplus"   -- optional: makes normal y/p use system clipboard
vim.g.clipboard = "win32yank"

vim.g.mapleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "neovim/nvim-lspconfig" },

  -- Telescope: fuzzy finder for files, symbols, grep, etc.
  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      local telescope = require("telescope")
      local builtin = require("telescope.builtin")

      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { preview_width = 0.5 },
          file_previewer = require("telescope.previewers").vim_buffer_cat.new,
          grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
        },
      })
      telescope.load_extension("fzf")

      -- Keymaps
      vim.keymap.set("n", "<C-p>", builtin.lsp_document_symbols, { desc = "Search symbols in file" })
      vim.keymap.set("n", "<C-S-p>", builtin.lsp_workspace_symbols, { desc = "Search symbols in workspace" })
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
  },

  -- Add Gruvbox (from earlier)
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    config = function()
      require("gruvbox").setup({ contrast = "hard" })
      vim.cmd("colorscheme gruvbox")
    end,
  },

  -- NEW: nvim-tree sidebar
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",  -- use latest
    lazy = false,   -- load immediately so it's always ready
    dependencies = {
      "nvim-tree/nvim-web-devicons",  -- icons in the tree
    },
    config = function()
      require("nvim-tree").setup({
        view = {
          side = "left",              -- left sidebar
          width = 35,                 -- adjust width as you like
        },
        renderer = {
          group_empty = true,         -- collapse empty folders
          highlight_git = true,       -- color git status
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
            },
          },
        },
        filters = {
          dotfiles = false,           -- show .git, .gitignore etc. (toggle with H)
        },
        git = {
          enable = true,
          ignore = false,
        },
        actions = {
          open_file = {
            quit_on_open = false,     -- keep tree open after opening file
          },
        },
      })

      -- Optional: keymap to toggle the sidebar (like VS Code Ctrl+B)
      vim.keymap.set("n", "<C-b>", ":NvimTreeToggle<CR>", { desc = "Toggle File Explorer" })
      -- Or auto-open on startup if you want:
      -- vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = function() require("nvim-tree.api").tree.open() end })
    end,
  },
})

-- Load LSP configuration
require("lsp")
