-- Keep Neovim configuration free of Tree-sitter dependencies.
-- AstroNvim enables a few Tree-sitter based plugins by default; disable them here
-- and rely on LSP, built-in Vim syntax, and lightweight non-Tree-sitter plugins.
---@type LazySpec
return {
  { "nvim-treesitter/nvim-treesitter", enabled = false },
  { "nvim-treesitter/nvim-treesitter-textobjects", enabled = false },
  { "windwp/nvim-ts-autotag", enabled = false },
}
