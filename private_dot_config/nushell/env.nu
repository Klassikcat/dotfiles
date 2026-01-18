# env.nu
#
# Installed by:
# version = "0.109.1"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.

$env.PATH = ($env.PATH | split row (char esep)
  | append $"($env.HOME)/.opencode/bin"
  | append $"($env.HOME)/.bun/bin"
  | append $"($env.HOME)/.local/bin"
  | append $"($env.HOME)/bin"
  | append "/home/linuxbrew/.linuxbrew/bin"
  | append "/home/linuxbrew/.linuxbrew/sbin"
  | append $"($env.HOME)/.cargo/bin"
  | append $"($env.HOME)/go/bin"
  | append $"($env.HOME)/.local/share/JetBrains/Toolbox/scripts"
)

$env.EDITOR = "vim"
$env.VISUAL = "vim"
$env.LIBVA_DRIVER_NAME = "nvidia"
$env.NVD_BACKEND = "direct"
$env.SYSTEMD_EDITOR = "vim"
$env.BUN_INSTALL = $"($env.HOME)/.bun"

# Starship prompt
mkdir ~/.cache/starship
starship init nu | save -f ~/.cache/starship/init.nu
$env.STARSHIP_SHELL = "nu"
$env.PROMPT_COMMAND = {|| 
    "\n" + (if $env.LAST_EXIT_CODE? != null { 
        starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)' | str trim
    } else {
        starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=0' | str trim
    })
}
$env.PROMPT_COMMAND_RIGHT = {|| starship prompt --right --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)' | str trim }
$env.PROMPT_INDICATOR = " "
$env.PROMPT_INDICATOR_VI_INSERT = " "
$env.PROMPT_INDICATOR_VI_NORMAL = " "
$env.PROMPT_MULTILINE_INDICATOR = "::: "
