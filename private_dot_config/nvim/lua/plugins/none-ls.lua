-- Customize None-ls sources

---@type LazySpec
return {
  "nvimtools/none-ls.nvim",
  opts = function(_, opts)
    -- opts variable is the default configuration table for the setup function call
    local null_ls = require "null-ls"

    -- Check supported formatters and linters
    -- https://github.com/nvimtools/none-ls.nvim/tree/main/lua/null-ls/builtins/formatting
    -- https://github.com/nvimtools/none-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics

    -- Only insert new sources, do not replace the existing ones
    -- (If you wish to replace, use `opts.sources = {}` instead of the `list_insert_unique` function)
    opts.sources = require("astrocore").list_insert_unique(opts.sources, {
      -- Set a formatter
      -- null_ls.builtins.formatting.stylua,
      -- null_ls.builtins.formatting.prettier,
      
      -- Add mypy diagnostics if available in virtual environment
      (function()
        local virtual_env = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
        if virtual_env then
          local mypy_path = virtual_env .. "/bin/mypy"
          -- Check if mypy exists in virtual environment
          local file = io.open(mypy_path, "r")
          if file then
            file:close()
            return null_ls.builtins.diagnostics.mypy.with({
              command = mypy_path,
              extra_args = function()
                return { "--python-executable", virtual_env .. "/bin/python" }
              end,
            })
          else
            -- Try to use mypy via uv if available
            local handle = io.popen("which uv 2>/dev/null")
            local uv_path = handle:read("*a"):gsub("%s+", "")
            handle:close()
            
            if uv_path ~= "" then
              -- Check if mypy is available via uv
              local uv_check = io.popen("cd " .. vim.fn.getcwd() .. " && uv pip list 2>/dev/null | grep -q mypy && echo 'found' || echo 'not found'")
              local result = uv_check:read("*a"):gsub("%s+", "")
              uv_check:close()
              
              if result == "found" then
                return null_ls.builtins.diagnostics.mypy.with({
                  command = "uv",
                  args = { "run", "mypy", "$FILENAME" },
                  extra_args = function()
                    return { "--python-executable", virtual_env .. "/bin/python" }
                  end,
                })
              end
            end
          end
        end
        return nil
      end)(),
    })
  end,
}
