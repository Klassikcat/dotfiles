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

$env.OPENCODE_DISABLE_CLAUDE_CODE = "1"

$env.PATH = ($env.PATH | split row (char esep)
  | prepend ($env.HOME | path join ".npm-global" "bin")
  | append $"($env.HOME)/.opencode/bin"
  | append $"($env.HOME)/.bun/bin"
  | append $"($env.HOME)/.local/bin"
  | append $"($env.HOME)/bin"
  | append (if ("/home/linuxbrew/.linuxbrew/bin" | path exists) { "/home/linuxbrew/.linuxbrew/bin" } else if ("/opt/homebrew/bin" | path exists) { "/opt/homebrew/bin" } else { "" })
  | append (if ("/home/linuxbrew/.linuxbrew/sbin" | path exists) { "/home/linuxbrew/.linuxbrew/sbin" } else if ("/opt/homebrew/sbin" | path exists) { "/opt/homebrew/sbin" } else { "" })
  | where $it != ""
  | append $"($env.HOME)/.cargo/bin"
  | append $"($env.HOME)/go/bin"
  | append $"($env.HOME)/.local/share/JetBrains/Toolbox/scripts"
  | append $"($env.HOME)/.nvm/versions/node/v24.12.0/bin"
  | append $"($env.HOME)/.lmstudio/bin"
)

# nvm default Node.js on startup (so new Nushell sessions use the default)
let nvm_dir = ($env.HOME | path join ".nvm")
let nvm_script = if ("/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh" | path exists) {
  "/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh"
} else if ("/opt/homebrew/opt/nvm/nvm.sh" | path exists) {
  "/opt/homebrew/opt/nvm/nvm.sh"
} else {
  ($nvm_dir | path join "nvm.sh")
}
let nvm_default_node = (bash -lc $'export NVM_DIR="($nvm_dir)"; mkdir -p "$NVM_DIR"; if [ -s "($nvm_script)" ]; then . "($nvm_script)"; nvm which default 2>/dev/null || true; fi' | str trim)
if $nvm_default_node != "" and ($nvm_default_node | path exists) {
  let nvm_default_bin = ($nvm_default_node | path dirname)
  $env.NVM_DIR = $nvm_dir
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

# direnv: cd 시 .envrc 자동 로드 (NCP 자격증명 주입 등)
$env.config = ($env.config? | default {} | upsert hooks {
    pre_prompt: [{ ||
        if (which direnv | is-empty) { return }
        direnv export json | from json | default {} | load-env
    }]
})

# Podman rootless socket → k3d / docker 호환 CLI
$env.DOCKER_HOST = $"unix:///run/user/(id -u | str trim)/podman/podman.sock"
$env.DOCKER_SOCK = $"/run/user/(id -u | str trim)/podman/podman.sock"  # k3d: 노드 컨테이너에 마운트할 소켓 경로
