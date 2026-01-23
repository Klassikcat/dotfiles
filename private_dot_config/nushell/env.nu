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
  | append $"($env.HOME)/.nvm/versions/node/v24.12.0/bin"
)

# nvm default Node.js on startup (so new Nushell sessions use the default)
let nvm_default_node = (bash -lc 'export NVM_DIR="$HOME/.nvm"; if [ -s "$NVM_DIR/nvm.sh" ]; then . "$NVM_DIR/nvm.sh"; nvm which default; fi' | str trim)
if $nvm_default_node != "" and ($nvm_default_node | path exists) {
  let nvm_default_bin = ($nvm_default_node | path dirname)
  $env.NVM_DIR = ($env.HOME | path join ".nvm")
  $env.NVM_BIN = $nvm_default_bin
  $env.PATH = ($env.PATH | split row (char esep) | where {|p| ($p | str contains "/.nvm/versions/node/") == false } | prepend $nvm_default_bin | str join (char esep))
}


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

# LS_COLORS configured for visibility in both Light and Dark modes
# Directories: Bold Blue (1;34)
# Symlinks: Bold Magenta (1;35)
# Executables: Bold Green (1;32)
# Archives: Bold Red (1;31)
# Images/Docs: Bold Magenta (1;35)
# Regular files: Default (0)
$env.LS_COLORS = "di=1;34:ln=1;35:so=1;31:pi=33:ex=1;32:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43:fi=0:*.tar=1;31:*.zip=1;31:*.gz=1;31:*.bz2=1;31:*.xz=1;31:*.rpm=1;31:*.jar=1;31:*.png=1;35:*.jpg=1;35:*.gif=1;35:*.rs=1;35:*.py=1;35:*.js=1;35:*.ts=1;35:*.nu=1;35:*.md=1;35:*.json=1;35:*.yaml=1;35:*.toml=1;35"
