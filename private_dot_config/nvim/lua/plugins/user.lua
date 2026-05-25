-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

---@type LazySpec
return {

  -- == Examples of Adding Plugins ==

  -- catppuccin colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "auto", -- latte, frappe, macchiato, mocha
        background = { -- :h background
          light = "latte",
          dark = "mocha",
        },
        transparent_background = false, -- disable transparent background
        show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
        term_colors = false, -- sets terminal colors (e.g. `g:terminal_color_0`)
        dim_inactive = {
          enabled = false, -- dims the background color of inactive window
          shade = "dark",
          percentage = 0.15, -- percentage of the shade to apply to the inactive window
        },
        no_italic = false, -- Force no italic
        no_bold = false, -- Force no bold
        no_underline = false, -- Force no underline
        styles = { -- Handles the styles of general hi groups (see `:h highlight-args`):
          comments = { "italic" }, -- Change the style of comments
          conditionals = { "italic" },
          loops = {},
          functions = {},
          keywords = {},
          strings = {},
          variables = {},
          numbers = {},
          booleans = {},
          properties = {},
          types = {},
          operators = {},
        },
        lsp_styles = { -- Handles the style of specific lsp hl groups (see `:h lsp-highlight`).
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
            ok = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
            ok = { "underline" },
          },
          inlay_hints = {
            background = true,
          },
        },
        color_overrides = {},
        custom_highlights = function(colors)
          return {
            -- Make only the main editor area transparent
            Normal = { bg = "NONE" },           -- Main editor background
            NormalNC = { bg = "NONE" },         -- Non-current editor background
            SignColumn = { bg = "NONE" },       -- Sign column (left gutter)
            
            -- Make Neo-tree transparent
            NeoTreeNormal = { bg = "NONE" },     -- Neo-tree main background
            NeoTreeNormalNC = { bg = "NONE" },   -- Neo-tree non-current background
            NeoTreeWinSeparator = { bg = "NONE", fg = colors.surface0 }, -- Window separator
            
            -- Keep other areas with background colors
            -- Telescope, etc. will keep their default backgrounds
          }
        end,
        default_integrations = true,
        integrations = {
          cmp = true,
          gitsigns = true,
          nvimtree = true,
          notify = false,
          mini = {
            enabled = true,
            indentscope_color = "",
          },
        },
      })
      
      -- setup must be called before loading
      vim.cmd.colorscheme "catppuccin"
    end,
  },

  -- Auto dark mode plugin
  {
    "f-person/auto-dark-mode.nvim",
    dependencies = { "catppuccin/nvim" },
    opts = {
      update_interval = 1000,
      set_dark_mode = function()
        vim.api.nvim_set_option("background", "dark")
        vim.cmd("colorscheme catppuccin-mocha")
      end,
      set_light_mode = function()
        vim.api.nvim_set_option("background", "light")
        vim.cmd("colorscheme catppuccin-latte")
      end,
    },
  },

  -- codecompanion.nvim for AI-powered coding assistance
  {
    "olimorris/codecompanion.nvim",
    opts = {
      system_prompt = "You are a principal software engineer. Always respond in korean unless user explicitly said 'please respond in {language}'",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },

  -- Minimap alternative without Tree-sitter dependency.
  {
    "echasnovski/mini.map",
    version = false,
    keys = {
      { "<leader>mm", function() require("mini.map").toggle() end, desc = "Toggle minimap" },
      { "<leader>mo", function() require("mini.map").open() end, desc = "Open minimap" },
      { "<leader>mc", function() require("mini.map").close() end, desc = "Close minimap" },
    },
    opts = function()
      local map = require "mini.map"
      return {
        integrations = {
          map.gen_integration.builtin_search(),
          map.gen_integration.diagnostic(),
        },
        symbols = {
          encode = map.gen_encode_symbols.dot("4x2"),
        },
        window = {
          show_integration_count = false,
          width = 10,
        },
      }
    end,
  },

  "andweeb/presence.nvim",

  -- Symbol outline without Tree-sitter: prefer LSP, then markdown/man backends.
  {
    "stevearc/aerial.nvim",
    opts = function(_, opts)
      opts.backends = { "lsp", "markdown", "man" }
      return opts
    end,
  },

  -- Markdown alternatives that do not depend on Tree-sitter.
  -- Browser preview replacement for render-markdown.nvim.
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    ft = { "markdown" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
  },
  -- In-editor terminal Markdown rendering through the external `glow` CLI.
  {
    "ellisonleao/glow.nvim",
    cmd = "Glow",
    ft = { "markdown" },
    keys = {
      { "<leader>mp", "<cmd>Glow<cr>", desc = "Markdown preview with Glow" },
    },
    opts = {
      glow_path = "glow",
      border = "rounded",
      style = "dark",
      pager = false,
      width = 120,
      height = 100,
      width_ratio = 0.9,
      height_ratio = 0.9,
    },
  },
  -- Classic Vim syntax/conceal for Markdown buffers.
  {
    "preservim/vim-markdown",
    ft = { "markdown" },
    init = function()
      vim.g.vim_markdown_folding_disabled = 1
      vim.g.vim_markdown_conceal = 0
      vim.g.vim_markdown_conceal_code_blocks = 0
    end,
  },

  -- HTML/XML tag closing without nvim-ts-autotag/Tree-sitter.
  {
    "alvan/vim-closetag",
    ft = { "html", "xml", "javascriptreact", "typescriptreact", "vue", "svelte" },
    init = function()
      vim.g.closetag_filenames = "*.html,*.xml,*.jsx,*.tsx,*.vue,*.svelte"
    end,
  },

  -- Lightweight indent guides with Tree-sitter based scope disabled.
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = { scope = { enabled = false } },
  },
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function() require("lsp_signature").setup() end,
  },

  -- == Examples of Overriding Plugins ==

  -- customize dashboard options
  {
    "folke/snacks.nvim",
    opts = {
      -- snacks.indent/scope uses Tree-sitter parsing; use indent-blankline instead.
      indent = { enabled = false },
      dashboard = {
        preset = {
          header = table.concat({
            " █████  ███████ ████████ ██████   ██████ ",
            "██   ██ ██         ██    ██   ██ ██    ██",
            "███████ ███████    ██    ██████  ██    ██",
            "██   ██      ██    ██    ██   ██ ██    ██",
            "██   ██ ███████    ██    ██   ██  ██████ ",
            "",
            "███    ██ ██    ██ ██ ███    ███",
            "████   ██ ██    ██ ██ ████  ████",
            "██ ██  ██ ██    ██ ██ ██ ████ ██",
            "██  ██ ██  ██  ██  ██ ██  ██  ██",
            "██   ████   ████   ██ ██      ██",
          }, "\n"),
        },
      },
    },
  },

  -- You can disable default plugins as follows:
  { "max397574/better-escape.nvim", enabled = false },

  -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom luasnip configuration such as filetype extend or custom snippets
      local luasnip = require "luasnip"
      luasnip.filetype_extend("javascript", { "javascriptreact" })
      
      -- Load custom snippets from ~/.config/nvim/snippets/
      require("luasnip.loaders.from_lua").lazy_load({ paths = "~/.config/nvim/snippets" })
    end,
  },

  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom autopairs configuration such as custom rules
      local npairs = require "nvim-autopairs"
      local Rule = require "nvim-autopairs.rule"
      local cond = require "nvim-autopairs.conds"
      npairs.add_rules(
        {
          Rule("$", "$", { "tex", "latex" })
            -- don't add a pair if the next character is %
            :with_pair(cond.not_after_regex "%%")
            -- don't add a pair if  the previous character is xxx
            :with_pair(
              cond.not_before_regex("xxx", 3)
            )
            -- don't move right when repeat character
            :with_move(cond.none())
            -- don't delete if the next character is xx
            :with_del(cond.not_after_regex "xx")
            -- disable adding a newline when you press <cr>
            :with_cr(cond.none()),
        },
        -- disable for .vim files, but it work for another filetypes
        Rule("a", "a", "-vim")
      )
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = function(_, opts)
      -- Check the OS and architecture
      local uname = vim.loop.os_uname()
      local os = uname.sysname
      local arch = uname.machine
      if os == "Linux" and arch == "aarch64" then
        -- Remove clangd from the ensure_installed list only for Linux ARM
        local new_ensure_installed = {}
        for _, pkg in ipairs(opts.ensure_installed) do
          if pkg ~= "clangd" then
            table.insert(new_ensure_installed, pkg)
          end
        end
        opts.ensure_installed = new_ensure_installed
      end
      return opts
    end,
  },
}
