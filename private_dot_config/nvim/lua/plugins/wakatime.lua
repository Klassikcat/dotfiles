---@type LazySpec
return {
  "wakatime/vim-wakatime",
  lazy = false, -- Load immediately to track all activity
  config = function()
    -- Optional: Set wakatime configuration
    vim.g.wakatime_PythonBinary = '/usr/bin/python3'  -- Adjust python path if needed
  end,
}