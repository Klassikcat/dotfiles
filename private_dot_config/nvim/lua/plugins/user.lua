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

  -- codewindow.nvim for minimap-style code overview
  {
    "gorbit99/codewindow.nvim",
    config = function()
      local codewindow = require('codewindow')
      codewindow.setup()
      codewindow.apply_default_keybinds()
    end,
  },

  "andweeb/presence.nvim",

  -- render-markdown.nvim for beautiful markdown rendering
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      -- Whether markdown should be rendered by default when opening markdown files
      enabled = true,
      -- Modes that will show a rendered view of markdown
      render_modes = { 'n', 'c', 't' },
      -- Filetypes this plugin will run on
      file_types = { "markdown", "codecompanion" },
      -- Anti-conceal: show raw markdown on cursor line
      anti_conceal = {
        enabled = true,
      },
      -- Enable markdown injection for various contexts
      injections = {
        -- Built-in gitcommit injection
        gitcommit = {
          enabled = true,
          query = [[
            ((message) @injection.content
                (#set! injection.combined)
                (#set! injection.include-children)
                (#set! injection.language "markdown"))
          ]],
        },
        -- Custom injection for CodeCompanion or similar tools
        codecompanion = {
          enabled = true,
          query = [[
            ((content) @injection.content
                (#set! injection.combined)
                (#set! injection.include-children)
                (#set! injection.language "markdown"))
          ]],
        },
      },
      -- Headings configuration
      heading = {
        enabled = true,
        sign = true,
        position = "overlay",
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
        width = "full",
        backgrounds = {
          "RenderMarkdownH1Bg",
          "RenderMarkdownH2Bg",
          "RenderMarkdownH3Bg",
          "RenderMarkdownH4Bg",
          "RenderMarkdownH5Bg",
          "RenderMarkdownH6Bg",
        },
      },
      -- Code blocks
      code = {
        enabled = true,
        sign = true,
        style = "full",
        language_icon = true,
        language_name = true,
        width = "full",
      },
      -- Bullet points
      bullet = {
        enabled = true,
        icons = { "●", "○", "◆", "◇" },
      },
      -- Checkboxes
      checkbox = {
        enabled = true,
        unchecked = {
          icon = "󰄱 ",
        },
        checked = {
          icon = "󰱒 ",
        },
      },
      -- Block quotes
      quote = {
        enabled = true,
        icon = "▋",
      },
      -- Tables
      pipe_table = {
        enabled = true,
        style = "full",
        cell = "padded",
        border = {
          "┌", "┬", "┐",
          "├", "┼", "┤",
          "└", "┴", "┘",
          "│", "─",
        },
      },
      -- Links
      link = {
        enabled = true,
      },
      -- Horizontal rules
      dash = {
        enabled = true,
        icon = "─",
        width = "full",
      },
      -- Window options for rendering
      win_options = {
        conceallevel = {
          default = vim.o.conceallevel,
          rendered = 3,
        },
        concealcursor = {
          default = vim.o.concealcursor,
          rendered = "",
        },
      },
      -- Override settings for different buffer types
      overrides = {
        buftype = {
          -- CodeCompanion and other special buffers
          nofile = {
            enabled = true,
            render_modes = true,
          },
          -- For prompt buffers that might be used by CodeCompanion
          prompt = {
            enabled = true,
            render_modes = true,
          },
        },
        -- Override for different filetypes
        filetype = {
          codecompanion = {
            enabled = true,
            render_modes = true,
          },
        },
      },
    },
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
