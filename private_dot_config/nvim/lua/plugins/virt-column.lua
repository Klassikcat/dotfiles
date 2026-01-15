-- virt-column provides a thin virtual vertical line at specified column
return {
  "lukas-reineke/virt-column.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("virt-column").setup({
      virtcolumn = "", -- Default: no line
      char = "▏", -- Character to use for the line (solid vertical bar)
    })
    
    -- Language-specific line length configurations
    local line_lengths = {
      python = 88,        -- Black formatter standard
      javascript = 100,   -- Modern JS standard
      typescript = 100,   -- Same as JS
      javascriptreact = 100,
      typescriptreact = 100,
      go = 100,          -- Go standard
      rust = 100,        -- Rust standard
      java = 120,        -- Java standard
      kotlin = 120,      -- Kotlin standard
      c = 80,            -- Traditional C standard
      cpp = 80,          -- Traditional C++ standard
      lua = 120,         -- Lua/Neovim config
      sh = 80,           -- Shell scripts
      bash = 80,         -- Bash scripts
      zsh = 80,          -- Zsh scripts
      markdown = 100,    -- Markdown files
      yaml = 120,        -- YAML files
      json = 120,        -- JSON files
    }
    
    -- Set up autocmd for each language
    vim.api.nvim_create_autocmd("FileType", {
      pattern = vim.tbl_keys(line_lengths),
      callback = function()
        local length = line_lengths[vim.bo.filetype]
        if length then
          vim.opt_local.colorcolumn = tostring(length)
          require("virt-column").setup_buffer({ virtcolumn = tostring(length) })
        end
      end,
    })
    
    -- Hide for unsupported file types
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "*" },
      callback = function()
        if not line_lengths[vim.bo.filetype] then
          vim.opt_local.colorcolumn = ""
        end
      end,
    })
  end,
}
