# config.nu
#
# Installed by:
# version = "0.109.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R
#

# Starship prompt is now initialized in env.nu

# Aliases from bashrc
def --wrapped grep [...args] { ^grep --color=auto ...$args }
def --wrapped fgrep [...args] { ^fgrep --color=auto ...$args }
def --wrapped egrep [...args] { ^egrep --color=auto ...$args }


# eza tree aliases with ignored folders
let EZA_IGNORE = 'node_modules|__pycache__|.venv|venv|env|.terraform*|.git|target|build|dist|out|bin|obj|.next|.nuxt|.svelte-kit|coverage|.nyc_output|*.pyc|*.pyo|*.pyd|.DS_Store|.idea|.vs|*.egg-info|.pytest_cache|.mypy_cache|.tox|.coverage|htmlcov|.sass-cache|.cache|.parcel-cache|vendor|Pods|DerivedData|.gradle|.m2|.cargo|.rustup'

alias t1 = eza --tree --level=1 --all --icons --ignore-glob=$EZA_IGNORE
alias t2 = eza --tree --level=2 --all --icons --ignore-glob=$EZA_IGNORE
alias t3 = eza --tree --level=3 --all --icons --ignore-glob=$EZA_IGNORE
alias t4 = eza --tree --level=4 --all --icons --git --ignore-glob=$EZA_IGNORE
alias t5 = eza --tree --level=5 --all --icons --git --ignore-glob=$EZA_IGNORE
alias ta = eza --tree --all --icons --git --long --header --ignore-glob=$EZA_IGNORE
alias l1 = eza --all --icons --ignore-glob=$EZA_IGNORE
alias l2 = eza --all --icons --long --header --git --ignore-glob=$EZA_IGNORE
alias t = eza --tree --level=2 --icons
alias tt = eza --tree --level=3 --icons --ignore-glob="__pycache__"
alias tall = eza --tree --level=2 --icons --all
alias tg = eza --tree --level=2 --icons --git-ignore
alias ts = eza --tree --level=2
alias td = eza --tree --level=2 --icons --only-dirs

def cdroot [] { cd ((git rev-parse --show-toplevel) | str trim) }
def gr [] { cd ((git rev-parse --show-toplevel) | str trim) }

# Catppuccin color palette
# Latte (light)
let catppuccin = {
    rosewater: "#dc8a78"
    flamingo: "#dd7878"
    pink: "#ea76cb"
    mauve: "#8839ef"
    red: "#d20f39"
    maroon: "#e64553"
    peach: "#fe640b"
    yellow: "#df8e1d"
    green: "#40a02b"
    teal: "#179299"
    sky: "#04a5e5"
    sapphire: "#209fb5"
    blue: "#1e66f5"
    lavender: "#7287fd"
    text: "#4c4f69"
    subtext1: "#5c5f77"
    subtext0: "#6c6f85"
    overlay2: "#7c7f93"
    overlay1: "#8c8fa1"
    overlay0: "#9ca0b0"
    surface2: "#acb0be"
    surface1: "#bcc0cc"
    surface0: "#ccd0da"
    base: "#eff1f5"
    mantle: "#e6e9ef"
    crust: "#dce0e8"
}

let catppuccin_theme = {
    separator: $catppuccin.overlay0
    leading_trailing_space_bg: $catppuccin.overlay0
    header: { fg: $catppuccin.blue attr: "b" }
    empty: $catppuccin.lavender
    bool: $catppuccin.lavender
    int: $catppuccin.peach
    duration: $catppuccin.peach
    date: $catppuccin.peach
    range: $catppuccin.peach
    float: $catppuccin.peach
    string: $catppuccin.green
    nothing: $catppuccin.lavender
    binary: $catppuccin.lavender
    cell-path: $catppuccin.lavender
    row_index: { fg: $catppuccin.mauve attr: "b" }
    record: $catppuccin.text
    list: $catppuccin.text
    block: $catppuccin.text
    hints: $catppuccin.overlay1
    search_result: { fg: $catppuccin.base bg: $catppuccin.yellow }
    shape_and: { fg: $catppuccin.pink attr: "b" }
    shape_binary: { fg: $catppuccin.pink attr: "b" }
    shape_block: { fg: $catppuccin.blue attr: "b" }
    shape_bool: $catppuccin.teal
    shape_closure: { fg: $catppuccin.green attr: "b" }
    shape_custom: $catppuccin.green
    shape_datetime: { fg: $catppuccin.teal attr: "b" }
    shape_directory: $catppuccin.teal
    shape_external: $catppuccin.teal
    shape_external_resolved: $catppuccin.teal
    shape_externalarg: { fg: $catppuccin.green attr: "b" }
    shape_filepath: $catppuccin.teal
    shape_flag: { fg: $catppuccin.blue attr: "b" }
    shape_float: { fg: $catppuccin.pink attr: "b" }
    shape_garbage: { fg: $catppuccin.base bg: $catppuccin.red attr: "b" }
    shape_glob_interpolation: { fg: $catppuccin.teal attr: "b" }
    shape_globpattern: { fg: $catppuccin.teal attr: "b" }
    shape_int: { fg: $catppuccin.pink attr: "b" }
    shape_internalcall: { fg: $catppuccin.teal attr: "b" }
    shape_keyword: { fg: $catppuccin.pink attr: "b" }
    shape_list: { fg: $catppuccin.teal attr: "b" }
    shape_literal: $catppuccin.blue
    shape_match_pattern: $catppuccin.green
    shape_matching_brackets: { attr: "u" }
    shape_nothing: $catppuccin.teal
    shape_operator: $catppuccin.peach
    shape_or: { fg: $catppuccin.pink attr: "b" }
    shape_pipe: { fg: $catppuccin.pink attr: "b" }
    shape_range: { fg: $catppuccin.peach attr: "b" }
    shape_record: { fg: $catppuccin.teal attr: "b" }
    shape_redirection: { fg: $catppuccin.pink attr: "b" }
    shape_signature: { fg: $catppuccin.green attr: "b" }
    shape_string: $catppuccin.green
    shape_string_interpolation: { fg: $catppuccin.teal attr: "b" }
    shape_table: { fg: $catppuccin.blue attr: "b" }
    shape_vardecl: { fg: $catppuccin.blue attr: "u" }
    shape_variable: $catppuccin.pink
}

# Nushell configuration updates
$env.config.buffer_editor = "vim"
$env.config.show_banner = false
$env.config.edit_mode = "vi"
$env.config.cursor_shape = {
    emacs: line
    vi_insert: line
    vi_normal: block
}
$env.config.color_config = $catppuccin_theme

alias mj-down = podman-compose down -v --remove-orphans -t 10
alias bat = batcat
alias cat = batcat --paging=never
alias catn = batcat --style=numbers --paging=never
alias catg = batcat --style=changes --paging=never
alias catl = batcat
alias catlatte = batcat --theme='Catppuccin Latte' --paging=never
alias catmocha = batcat --theme='Catppuccin Mocha' --paging=never
alias catfrappe = batcat --theme='Catppuccin Frappe' --paging=never
alias catmacchiato = batcat --theme='Catppuccin Macchiato' --paging=never
alias toggle-bar = pkill -SIGUSR1 waybar
alias toggle-theme = /home/shinjungtae/.local/bin/toggle-theme
alias fastfetch = /home/linuxbrew/.linuxbrew/bin/fastfetch
