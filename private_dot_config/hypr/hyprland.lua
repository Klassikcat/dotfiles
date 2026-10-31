-- Migrated from hyprland.conf (KooL dots, hyprlang) for Hyprland 0.57 Lua config.
-- The old .conf files are kept: hyprlock, wallust, hyprdynamicmonitors and KooL scripts still read/write them.

local home = os.getenv("HOME")
local hypr = home .. "/.config/hypr"
-- exec_cmd runs through `sh -c`, so $HOME expands inside command strings
local scriptsDir = "$HOME/.config/hypr/scripts"
local UserScripts = "$HOME/.config/hypr/UserScripts"
local mainMod = "SUPER"
local term = "kitty"
local files = "thunar"

-- Read `$name = value` / `key = value` lines from a hyprlang file still written by an external tool.
-- ponytail: tiny line parser, no nesting/variables; replace once wallust/hyprdynamicmonitors emit Lua.
local function read_hyprlang(path)
    local out = {}
    local f = io.open(path, "r")
    if not f then return out end
    for line in f:lines() do
        line = line:gsub("%s+#.*$", "")
        local k, v = line:match("^%s*([%$%w_%.]+)%s*=%s*(.-)%s*$")
        if k then out[#out + 1] = { k, v } end
    end
    f:close()
    return out
end

------------------
---- MONITORS ----
------------------
-- monitors.conf is written by hyprdynamicmonitors (hyprlang). It runs `hyprctl reload` after applying.
-- Format: monitor=OUTPUT,mode,position,scale[,transform,N][,vrr,N][,bitdepth,N][,cm,X]  or  OUTPUT,disable
for _, kv in ipairs(read_hyprlang(hypr .. "/monitors.conf")) do
    local k, v = kv[1], kv[2]
    if k == "monitor" then
        local p = {}
        for field in (v .. ","):gmatch("(.-),") do p[#p + 1] = field end
        if p[2] == "disable" then
            hl.monitor({ output = p[1], disabled = true })
        else
            local spec = { output = p[1], mode = p[2], position = p[3], scale = tonumber(p[4]) or p[4] }
            for i = 5, #p - 1, 2 do
                spec[p[i]] = tonumber(p[i + 1]) or p[i + 1]
            end
            hl.monitor(spec)
        end
    elseif k == "exec" then
        -- the profile's exec (swww repaint) must see the new geometry; running it at parse time
        -- paints rotated outputs with the pre-rotation size (stretched wallpaper)
        -- events can arrive back-to-back (dock plug, rotate): serialize so the run started by the
        -- last event finishes last; parallel swww runs leave a stale-size (garbled) buffer
        -- and wait until swww-daemon has received the new output sizes (it lags the event)
        local cmd = "flock \"$XDG_RUNTIME_DIR/hypr-monitor-exec.lock\" -c '"
            .. scriptsDir .. "/WaitSwwwGeometry.sh; " .. v:gsub("'", "'\\''") .. "'"
        hl.on("monitor.layout_changed", function() hl.exec_cmd(cmd) end)
    end
end
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- hyprland.conf: per-monitor scrolling layout (UserSettings.conf)
local scrollRule = hl.workspace_rule({ workspace = "m[desc:LG Electronics LG ULTRAFINE 210NTGY5V831]", layout = "scrolling" })
hl.workspace_rule({ workspace = "m[desc:Dell Inc. DELL U2723QE 3HB38H3]", layout = "scrolling" })
hl.workspace_rule({ workspace = "m[desc:Samsung Display Corp. ATNA33AA08-0]", layout = "scrolling" })
-- Layouts are only resolved on workspace creation / prop refresh, so a workspace moved by an
-- undock (via the FALLBACK output) kept its old layout until `hyprctl reload`.
-- Toggling a rule schedules one prop refresh, which re-resolves layouts against current monitors.
hl.on("workspace.move_to_monitor", function()
    scrollRule:set_enabled(false)
    scrollRule:set_enabled(true)
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("EDITOR", "nvim")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "0")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "kde") -- old config set qt5ct then kde; last one won
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("QT_QUICK_CONTROLS_STYLE", "org.hyprland.style")
hl.env("GDK_SCALE", "1")
hl.env("QT_SCALE_FACTOR", "1")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "40")
hl.env("HYPRCURSOR_SIZE", "40")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("INPUT_METHOD", "fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("GLFW_IM_MODULE", "fcitx")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("GSK_RENDERER", "ngl")
hl.env("AQ_NO_MODIFIERS", "1")

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    for _, cmd in ipairs({
        hypr .. "/initial-boot.sh",
        "swww-daemon --format xrgb",
        scriptsDir .. "/SwwwMonitorRestore.sh",
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE GTK_IM_MODULE QT_IM_MODULE XMODIFIERS INPUT_METHOD SDL_IM_MODULE GLFW_IM_MODULE MOZ_ENABLE_WAYLAND",
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE GTK_IM_MODULE QT_IM_MODULE XMODIFIERS INPUT_METHOD SDL_IM_MODULE GLFW_IM_MODULE MOZ_ENABLE_WAYLAND",
        "systemctl --user start hyprland-session.target",
        scriptsDir .. "/AutoRotate.sh",
        "systemctl --user start hyprland-theme@sunrise-light.service hyprland-theme@sunset-dark.service",
        scriptsDir .. "/Dropterminal.sh kitty &",
        scriptsDir .. "/Polkit.sh",
        "nm-applet --indicator",
        "ags",
        "blueman-applet",
        "qs",
        "wl-paste --type text --watch cliphist store",
        "wl-paste --type image --watch cliphist store",
        "fcitx5 -d",
        "systemctl --user start hypridle.service",
        "$HOME/.local/bin/hyprland-theme-init.sh",
        "$HOME/.local/bin/brightness-init.sh",
    }) do
        hl.exec_cmd(cmd)
    end
end)

-----------------------
---- LOOK AND FEEL ----
-----------------------
-- Colors come from wallust (still writes hyprlang because hyprlock sources the same file)
local color = {}
for _, kv in ipairs(read_hyprlang(hypr .. "/wallust/wallust-hyprland.conf")) do
    color[kv[1]:gsub("^%$", "")] = kv[2]
end
local function c(name, fallback) return color[name] or fallback end

hl.config({
    general = {
        border_size = 2,
        gaps_in = 2,
        gaps_out = 4,
        col = {
            active_border = c("color12", "rgb(736C77)"),
            inactive_border = c("color10", "rgb(1C1D24)"),
        },
        resize_on_border = true,
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 0.9,
        fullscreen_opacity = 1.0,
        dim_inactive = true,
        dim_strength = 0.1,
        dim_special = 0.8,
        shadow = {
            enabled = true,
            range = 3,
            render_power = 1,
            color = c("color12", "rgb(736C77)"),
            color_inactive = c("color10", "rgb(1C1D24)"),
        },
        blur = {
            enabled = true,
            size = 6,
            passes = 2,
            ignore_opacity = true,
            new_optimizations = true,
            xray = true, -- blur sampled from bottom layer once; in tiling visually identical, ~16% gfx saved
            special = true,
            popups = true,
        },
    },

    group = {
        col = { border_active = c("color15", "rgb(D4CFD4)") },
        groupbar = { col = { active = c("color0", "rgb(3F3F40)") } },
    },

    animations = { enabled = true },

    dwindle = {
        preserve_split = true,
        special_scale_factor = 0.8,
    },

    master = {
        new_status = "master",
        new_on_top = true,
        mfact = 0.5,
    },

    input = {
        kb_layout = "us",
        repeat_rate = 50,
        repeat_delay = 300,
        sensitivity = 0,
        numlock_by_default = true,
        left_handed = false,
        follow_mouse = 1,
        float_switch_override_focus = 0,
        touchpad = {
            disable_while_typing = true,
            natural_scroll = true,
            clickfinger_behavior = false,
            middle_button_emulation = false,
            tap_to_click = true,
            drag_lock = 0,
        },
        touchdevice = { enabled = true },
        tablet = { transform = 0, left_handed = false },
    },

    gestures = {
        workspace_swipe_distance = 500,
        workspace_swipe_invert = true,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_cancel_ratio = 0.5,
        workspace_swipe_create_new = true,
        workspace_swipe_forever = true,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 2,
        mouse_move_enables_dpms = true,
        enable_swallow = false,
        swallow_regex = "^(kitty)$",
        focus_on_activate = false,
        initial_workspace_tracking = 0,
        middle_click_paste = false,
        enable_anr_dialog = true,
        anr_missed_pings = 15, -- default 1 is too low
        allow_session_lock_restore = true, -- prevent lockscreen crash when resuming from suspend
    },

    binds = {
        workspace_back_and_forth = true,
        allow_workspace_cycles = true,
        pass_mouse_when_bound = false,
    },

    xwayland = {
        enabled = true,
        force_zero_scaling = false,
    },

    render = { direct_scanout = 0 },

    cursor = {
        sync_gsettings_theme = true,
        no_hardware_cursors = 0,
        enable_hyprcursor = true,
        warp_on_change_workspace = 2,
        no_warps = false,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.device({ name = "asue1209:00-04f3:319f-touchpad", enabled = true })
hl.device({ name = "at-translated-set-2-keyboard", kb_options = "ctrl:swapcaps" })

--------------------
---- ANIMATIONS ----
--------------------
-- UserAnimations.conf stays hyprlang: scripts/Animations.sh copies presets from animations/*.conf into it.
--   enabled = yes|no
--   bezier = name, x0, y0, x1, y1
--   animation = leaf, on/off[, speed, curve[, style]]
local function split(v)
    local p = {}
    for field in (v .. ","):gmatch("%s*(.-)%s*,") do p[#p + 1] = field end
    return p
end
local truthy = { ["1"] = true, yes = true, on = true, ["true"] = true }
for _, kv in ipairs(read_hyprlang(hypr .. "/UserConfigs/UserAnimations.conf")) do
    local k, p = kv[1], split(kv[2])
    if k == "enabled" then
        hl.config({ animations = { enabled = truthy[p[1]] or false } })
    elseif k == "bezier" then
        hl.curve(p[1], { type = "bezier", points = { { tonumber(p[2]), tonumber(p[3]) }, { tonumber(p[4]), tonumber(p[5]) } } })
    elseif k == "animation" then
        local anim = { leaf = p[1], enabled = truthy[p[2]] or false }
        if anim.enabled and p[3] then
            anim.speed = math.min(tonumber(p[3]), 100) -- 0.57 caps speed at 100; old presets use 180 for borderangle loop
            anim.bezier = p[4]
            anim.style = p[5]
        end
        hl.animation(anim)
    end
end

---------------------
---- KEYBINDINGS ----
---------------------
local function bind(keys, dsp, opts) hl.bind(keys, dsp, opts) end
local function exec(keys, cmd, opts) hl.bind(keys, hl.dsp.exec_cmd(cmd), opts) end
local M = mainMod .. " + "
local repeating, locked = { repeating = true }, { locked = true }

-- configs/Keybinds.conf
bind(M .. "Q", hl.dsp.window.close())
exec(M .. "SHIFT + Q", scriptsDir .. "/KillActiveProcess.sh")
exec(M .. "L", scriptsDir .. "/LockScreen.sh")
exec("CTRL + ALT + P", scriptsDir .. "/Wlogout.sh")
exec(M .. "SHIFT + N", "swaync-client -t -sw")
exec(M .. "SHIFT + E", scriptsDir .. "/Kool_Quick_Settings.sh")

bind(M .. "CTRL + D", hl.dsp.layout("removemaster"))
bind(M .. "I", hl.dsp.layout("addmaster"))
bind(M .. "J", hl.dsp.layout("cyclenext"))
bind(M .. "K", hl.dsp.layout("cycleprev"))
bind(M .. "CTRL + Return", hl.dsp.layout("swapwithmaster"))
bind(M .. "SHIFT + I", hl.dsp.layout("togglesplit"))
bind(M .. "P", hl.dsp.window.pseudo())
bind(M .. "M", hl.dsp.layout("splitratio 0.3"))

bind(M .. "G", hl.dsp.group.toggle())
bind(M .. "CTRL + tab", hl.dsp.group.next())

bind("ALT + tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)

exec("XF86AudioRaiseVolume", scriptsDir .. "/Volume.sh --inc", { repeating = true, locked = true })
exec("XF86AudioLowerVolume", scriptsDir .. "/Volume.sh --dec", { repeating = true, locked = true })
exec("XF86AudioMicMute", scriptsDir .. "/Volume.sh --toggle-mic", locked)
exec("XF86AudioMute", scriptsDir .. "/Volume.sh --toggle", locked)
exec("XF86Sleep", "systemctl suspend", locked)
exec("XF86RFKill", scriptsDir .. "/AirplaneMode.sh", locked)
exec("XF86AudioPause", scriptsDir .. "/MediaCtrl.sh --pause", locked)
exec("XF86AudioPlay", scriptsDir .. "/MediaCtrl.sh --pause", locked)
exec("XF86AudioNext", scriptsDir .. "/MediaCtrl.sh --nxt", locked)
exec("XF86AudioPrev", scriptsDir .. "/MediaCtrl.sh --prv", locked)
exec("XF86AudioStop", scriptsDir .. "/MediaCtrl.sh --stop", locked)

exec(M .. "Print", scriptsDir .. "/ScreenShot.sh --now")
exec(M .. "SHIFT + Print", scriptsDir .. "/ScreenShot.sh --area")
exec(M .. "CTRL + Print", scriptsDir .. "/ScreenShot.sh --in5")
exec(M .. "CTRL + SHIFT + Print", scriptsDir .. "/ScreenShot.sh --in10")
exec("ALT + Print", scriptsDir .. "/ScreenShot.sh --active")
exec(M .. "SHIFT + S", scriptsDir .. "/ScreenShot.sh --swappy")

local dirs = { left = "left", right = "right", up = "up", down = "down" }
local resize = { left = { -50, 0 }, right = { 50, 0 }, up = { 0, -50 }, down = { 0, 50 } }
for key, dir in pairs(dirs) do
    bind(M .. "SHIFT + " .. key, hl.dsp.window.resize({ x = resize[key][1], y = resize[key][2], relative = true }), repeating)
    bind(M .. "CTRL + " .. key, hl.dsp.window.move({ direction = dir }))
    bind(M .. "ALT + " .. key, hl.dsp.window.swap({ direction = dir }))
    bind(M .. key, hl.dsp.focus({ direction = dir }))
end

bind(M .. "tab", hl.dsp.focus({ workspace = "m+1" }))
bind(M .. "SHIFT + tab", hl.dsp.focus({ workspace = "m-1" }))
bind(M .. "U", hl.dsp.workspace.toggle_special("special"))

-- code:10..19 = keys 1..0
for i = 1, 10 do
    local key = "code:" .. (i + 9)
    bind(M .. key, hl.dsp.focus({ workspace = tostring(i) }))
    bind(M .. "SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }))
    bind(M .. "CTRL + " .. key, hl.dsp.window.move({ workspace = tostring(i), follow = false }))
end
bind(M .. "bracketleft", hl.dsp.window.move({ workspace = "-1" }))
bind(M .. "bracketright", hl.dsp.window.move({ workspace = "+1" }))
bind(M .. "CTRL + bracketleft", hl.dsp.window.move({ workspace = "-1", follow = false }))
bind(M .. "CTRL + bracketright", hl.dsp.window.move({ workspace = "+1", follow = false }))

bind(M .. "mouse_down", hl.dsp.focus({ workspace = "e+1" }))
bind(M .. "mouse_up", hl.dsp.focus({ workspace = "e-1" }))
bind("SUPER + grave", hl.dsp.focus({ monitor = "+1" }))
bind("SUPER + SHIFT + grave", hl.dsp.focus({ monitor = "-1" }))

bind(M .. "mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(M .. "mouse:273", hl.dsp.window.resize(), { mouse = true })

-- UserConfigs/Laptops.conf
exec("XF86KbdBrightnessDown", scriptsDir .. "/BrightnessKbd.sh --dec", repeating)
exec("XF86KbdBrightnessUp", scriptsDir .. "/BrightnessKbd.sh --inc", repeating)
exec("XF86Launch1", "rog-control-center")
exec("XF86Launch3", "asusctl led-mode -n")
exec("XF86Launch4", "asusctl profile -n")
exec("XF86MonBrightnessDown", scriptsDir .. "/Brightness.sh --dec", repeating)
exec("XF86MonBrightnessUp", scriptsDir .. "/Brightness.sh --inc", repeating)
exec("XF86TouchpadToggle", scriptsDir .. "/TouchPad.sh")
exec(M .. "F6", scriptsDir .. "/ScreenShot.sh --now")
exec(M .. "SHIFT + F6", scriptsDir .. "/ScreenShot.sh --area")
exec(M .. "CTRL + F6", scriptsDir .. "/ScreenShot.sh --in5")
exec(M .. "ALT + F6", scriptsDir .. "/ScreenShot.sh --in10")
exec("ALT + F6", scriptsDir .. "/ScreenShot.sh --active")

-- UserConfigs/UserKeybinds.conf
bind(M .. "D", hl.dsp.window.float({ action = "toggle" }))
exec(M .. "B", 'xdg-open "https://"')
exec(M .. "A", "pkill rofi || true && ags -t 'overview'")
exec(M .. "Return", term)
exec(M .. "E", files)
exec(M .. "H", scriptsDir .. "/KeyHints.sh")
exec(M .. "ALT + R", scriptsDir .. "/Refresh.sh")
exec(M .. "ALT + E", scriptsDir .. "/RofiEmoji.sh")
exec(M .. "S", scriptsDir .. "/RofiSearch.sh")
exec(M .. "CTRL + S", "rofi -show window")
exec(M .. "ALT + O", scriptsDir .. "/ChangeBlur.sh")
exec(M .. "SHIFT + G", scriptsDir .. "/GameMode.sh")
exec(M .. "ALT + L", scriptsDir .. "/ChangeLayout.sh")
exec(M .. "ALT + V", scriptsDir .. "/ClipManager.sh")
exec(M .. "CTRL + R", scriptsDir .. "/RofiThemeSelector.sh")
exec(M .. "CTRL + SHIFT + R", "pkill rofi || true && " .. scriptsDir .. "/RofiThemeSelector-modified.sh")
bind(M .. "SHIFT + F", hl.dsp.window.fullscreen())
bind(M .. "CTRL + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
exec(M .. "SPACE", "pkill rofi || true && rofi -dpi 115 -show drun -modi drun,filebrowser,run,window")
exec(M .. "SHIFT + Return", "ghostty")
exec("mouse:274", "bash " .. UserScripts .. "/MiddlePan.sh down", { ignore_mods = true })
exec("mouse:274", "bash " .. UserScripts .. "/MiddlePan.sh up", { ignore_mods = true, release = true })

local function zoom(factor)
    return function()
        local z = math.max(hl.get_config("cursor.zoom_factor") or 1, 1)
        hl.config({ cursor = { zoom_factor = math.max(z * factor, 1) } })
    end
end
bind(M .. "ALT + mouse_down", zoom(2.0))
bind(M .. "ALT + mouse_up", zoom(0.5))

exec(M .. "CTRL + ALT + B", "pkill -SIGUSR1 waybar")
exec(M .. "F1", "pkill -SIGUSR1 waybar")
exec(M .. "CTRL + B", scriptsDir .. "/WaybarStyles.sh")
exec(M .. "ALT + B", scriptsDir .. "/WaybarLayout.sh")
exec(M .. "N", scriptsDir .. "/Hyprsunset.sh toggle")
exec(M .. "SHIFT + M", UserScripts .. "/RofiBeats.sh")
exec(M .. "ALT + P", UserScripts .. "/WallpaperSelect.sh")
exec("CTRL + ALT + W", UserScripts .. "/WallpaperRandom.sh")
bind(M .. "CTRL + O", hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }))
exec(M .. "SHIFT + K", scriptsDir .. "/KeyBinds.sh")
exec(M .. "SHIFT + A", scriptsDir .. "/Animations.sh")
exec(M .. "SHIFT + O", UserScripts .. "/ZshChangeTheme.sh")
exec("Alt_L + Shift_L", scriptsDir .. "/SwitchKeyboardLayout.sh", { locked = true, non_consuming = true })
exec("Shift_L + Alt_L", scriptsDir .. "/Tak0-Per-Window-Switch.sh", { locked = true, non_consuming = true })
exec(M .. "ALT + C", UserScripts .. "/RofiCalc.sh")

local monDirs = { F9 = "l", F10 = "r", F11 = "u", F12 = "d" }
for key, d in pairs(monDirs) do
    bind(M .. "CTRL + " .. key, hl.dsp.workspace.move({ monitor = d }))
    bind(M .. "SHIFT + " .. key, hl.dsp.window.move({ monitor = d }))
end
bind(M .. "comma", hl.dsp.focus({ monitor = "DP-3" }))
bind(M .. "period", hl.dsp.focus({ monitor = "DP-2" }))

exec("XF86MonBrightnessDown", "$HOME/.local/bin/brightness down")
exec("XF86MonBrightnessUp", "$HOME/.local/bin/brightness up")
exec("Scroll_Lock", "$HOME/.local/bin/brightness down") -- HHKB Fn+O
exec("Pause", "$HOME/.local/bin/brightness up") -- HHKB Fn+P

------------------------------
---- WINDOW / LAYER RULES ----
------------------------------
-- configs/WindowRules.conf: tags by class/title
local tagClasses = {
    browser = {
        "^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|[Ff]irefox-bin)$",
        "^([Gg]oogle-chrome(-beta|-dev|-unstable)?)$",
        "^(chrome-.+-Default)$",
        "^([Cc]hromium)$",
        "^([Mm]icrosoft-edge(-stable|-beta|-dev|-unstable))$",
        "^(Brave-browser(-beta|-dev|-unstable)?)$",
        "^([Tt]horium-browser|[Cc]achy-browser)$",
        "^(zen-alpha|zen)$",
    },
    notif = { "^(swaync-control-center|swaync-notification-window|swaync-client|class)$" },
    ["KooL-Settings"] = { "^(nwg-displays|nwg-look)$" },
    terminal = { "^(Alacritty|kitty|kitty-dropterm)$" },
    email = { "^([Tt]hunderbird|org.mozilla.Thunderbird)$", "^(eu.betterbird.Betterbird)$", "^(org.gnome.Evolution)$" },
    projects = {
        "^(codium|codium-url-handler|VSCodium)$",
        "^(VSCode|code|code-url-handler)$",
        "^(jetbrains-.+)$",
        "^(dev.zed.Zed|antigravity)$",
    },
    screenshare = { "^(com.obsproject.Studio)$" },
    im = {
        "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$",
        "^([Ff]erdium)$",
        "^([Ww]hatsapp-for-linux)$",
        "^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$",
        "^(teams-for-linux)$",
        "^(im.riot.Riot|Element)$",
    },
    games = { "^(gamescope)$", "^(steam_app_\\d+)$" },
    gamestore = { "^([Ss]team)$", "^(com.heroicgameslauncher.hgl)$" },
    ["file-manager"] = { "^([Tt]hunar|org.gnome.Nautilus|[Pp]cmanfm-qt)$", "^(app.drey.Warp)$" },
    wallpaper = { "^([Ww]aytrogen)$" },
    multimedia = { "^([Aa]udacious)$" },
    multimedia_video = { "^([Mm]pv|vlc)$" },
    settings = {
        "^(wihotspot(-gui)?)$",
        "^([Bb]aobab|org.gnome.[Bb]aobab)$",
        "^(gnome-disks|wihotspot(-gui)?)$",
        "^(file-roller|org.gnome.FileRoller)$",
        "^(nm-applet|nm-connection-editor|blueman-manager)$",
        "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$",
        "^(qt5ct|qt6ct)$",
        "(xdg-desktop-portal-gtk)",
        "^(org.kde.polkit-kde-authentication-agent-1)$",
        "^([Rr]ofi)$",
        "^(btrfs-assistant)$",
        "^(timeshift-gtk)$",
    },
    viewer = {
        "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter)$",
        "^(evince)$",
        "^(eog|org.gnome.Loupe)$",
    },
}
for tag, classes in pairs(tagClasses) do
    for _, cls in ipairs(classes) do
        hl.window_rule({ match = { class = cls }, tag = "+" .. tag })
    end
end
local tagTitles = {
    KooL_Cheat = { "^(KooL Quick Cheat Sheet)$" },
    KooL_Settings = { "^(KooL Hyprland Settings)$" },
    gamestore = { "^([Ll]utris)$" },
    settings = { "^(ROG Control)$", "(Kvantum Manager)" },
}
for tag, titles in pairs(tagTitles) do
    for _, t in ipairs(titles) do
        hl.window_rule({ match = { title = t }, tag = "+" .. tag })
    end
end

local function rule(match, effects)
    effects.match = match
    hl.window_rule(effects)
end
local function size(w, h) return "monitor_w*" .. w .. " monitor_h*" .. h end

rule({ tag = "multimedia_video" }, { no_blur = true, opacity = "1.0" })
rule({ tag = "multimedia" }, { no_blur = true, opacity = "1.0" })
rule({ tag = "KooL_Cheat" }, { center = true, float = true, size = size(0.65, 0.9) })
rule({ tag = "KooL-Settings" }, { center = true, float = true })
rule({ title = "^(ROG Control)$" }, { center = true })
rule({ title = "^(Keybindings)$" }, { center = true })
rule({ class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" }, { center = true })
rule({ class = "^([Ff]erdium)$" }, { center = true, float = true, size = size(0.6, 0.7) })
rule({ class = ".*" }, { idle_inhibit = "fullscreen" })

rule({ tag = "wallpaper" }, { float = true, center = true, size = size(0.7, 0.7) })
rule({ tag = "settings" }, { float = true, center = true, size = size(0.7, 0.7) })
rule({ tag = "viewer" }, { float = true, center = true })
rule({ class = "([Zz]oom|onedriver|onedriver-launcher)" }, { float = true })
rule({ class = "(org.gnome.Calculator|qalculate-gtk)" }, { float = true })
rule({ class = "^(mpv|com.github.rafostar.Clapper)$" }, { float = true })
rule({ class = "^([Qq]alculate-gtk)$" }, { float = true })
rule({ title = "^(Authentication Required)$" }, { float = true, center = true })
rule({ class = "(codium|codium-url-handler|VSCodium)", title = "negative:(.*codium.*|.*VSCodium.*)" }, { float = true })
rule({ class = "^(com.heroicgameslauncher.hgl)$", title = "negative:(Heroic Games Launcher)" }, { float = true })
rule({ class = "^([Ss]team)$", title = "negative:^([Ss]team)$" }, { float = true })
rule({ title = "^(Add Folder to Workspace)$" }, { float = true, size = size(0.7, 0.6), center = true })
rule({ title = "^(Save As)$" }, { float = true, size = size(0.7, 0.6), center = true })
rule({ initial_title = "(Open Files)" }, { float = true, size = size(0.7, 0.6) })
rule({ title = "^(SDDM Background)$" }, { float = true, center = true, size = size(0.16, 0.12) })
rule({ class = "^(yad)$" }, { float = true, center = true, size = size(0.2, 0.2) })
rule({ class = "^(hyprland-donate-screen)$" }, { float = true, center = true })

rule({ tag = "browser" }, { opacity = "0.99 0.8" })
rule({ tag = "projects" }, { opacity = "0.9 0.8" })
rule({ tag = "im" }, { opacity = "0.94 0.86" })
rule({ tag = "multimedia" }, { opacity = "0.94 0.86" })
rule({ tag = "file-manager" }, { opacity = "0.9 0.8" })
rule({ tag = "terminal" }, { opacity = "0.9 0.7" })
rule({ tag = "settings" }, { opacity = "0.8 0.7" })
rule({ tag = "viewer" }, { opacity = "0.82 0.75" })
rule({ tag = "wallpaper" }, { opacity = "0.9 0.7" })
rule({ class = "^(gedit|org.gnome.TextEditor|mousepad)$" }, { opacity = "0.8 0.7" })
rule({ class = "^(deluge)$" }, { opacity = "0.9 0.8" })
rule({ class = "^(seahorse)$" }, { opacity = "0.9 0.8" })

rule({ tag = "games" }, { no_blur = true, fullscreen = false })
rule({ class = "^(jetbrains-*)" }, { no_initial_focus = true })
rule({ title = "^(wind.*)$" }, { no_initial_focus = true })

rule({ class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" }, { size = size(0.6, 0.7), center = true })
rule({ title = "^(Picture-in-Picture)$" }, {
    float = true,
    move = "monitor_w*0.72 monitor_h*0.07",
    opacity = "0.95 0.75",
    pin = true,
    keep_aspect_ratio = true,
    size = size(0.3, 0.3),
})
rule({ class = "^(thunar)$", title = "^(File Operation Progress)$" }, { float = true, center = true, size = size(0.26, 0.18) })

-- UserConfigs/WindowRules.conf (user overrides, after the defaults)
rule({ class = "^(dev.zed.Zed)$" }, { opacity = "0.9 0.8" })
rule({ class = "^(kitty|kitty-dropterm)$" }, { opacity = "1.0 0.7" })
rule({ fullscreen = true }, { no_blur = true })

hl.layer_rule({ match = { namespace = "rofi" }, blur = true })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:overview" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.1 })
