-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- Customize Mason

---@type LazySpec
return {
  -- use mason-tool-installer for automatically installing Mason packages
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    -- overrides `require("mason-tool-installer").setup(...)`
    opts = {
      -- Make sure to use the names found in `:Mason`
      ensure_installed = {
        -- install language servers
        "lua-language-server",
        "python-lsp-server",     -- Python LSP (correct name)
        "basedpyright",          -- Python LSP with enhanced type checking (pyright fork)
        -- "mypy",                  -- Python type checker (removed due to version conflicts)
        "gopls",                 -- Go LSP
        "typescript-language-server", -- TypeScript/JavaScript LSP
        "kotlin-language-server", -- Kotlin LSP
        "clangd",                -- C/C++ LSP

        -- install formatters
        "stylua",
        "black",                 -- Python formatter
        "prettier",              -- JavaScript/TypeScript formatter

        -- install debuggers
        "debugpy",

        -- install any other package
        "tree-sitter-cli",
      },
    },
  },
}
