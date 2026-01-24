---@type LazySpec
return {
  "wakatime/vim-wakatime",
  lazy = false, -- Load immediately to track all activity
  config = function()
    -- Optional: Set wakatime configuration
    vim.g.wakatime_PythonBinary = vim.fn.exepath('python3') ~= '' and vim.fn.exepath('python3') or '/usr/bin/python3'
  end,
}