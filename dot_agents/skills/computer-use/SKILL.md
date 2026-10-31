---
name: computer-use
description: >-
  Inspect and operate local desktop apps on this Hyprland (Wayland) workstation
  from pi. Read the screen with grim screenshots analyzed via the read tool,
  list/focus/close windows with hyprctl, and interact with app UI through the
  AT-SPI accessibility tree (pyatspi): read visible UI, click controls via
  accessible actions, get/set values. Use for desktop app interaction such as
  "computer use", "read the screen", "what's open", "click/run a control in an
  app", "get app state", or checking UI before asserting. Not for web automation
  (use browser-use) or terminals (use bash).
---

# Computer use (pi on Hyprland/Wayland)

pi has no built-in desktop tools; drive this workstation with verified shell primitives. Always look before acting, and verify after.

## 1. Look

- Full screen: `grim /tmp/pi-cu.png` (also `grim -g "$(slurp -d)"` for a user-selected region).
- Then **read the PNG with the `read` tool** — pi attaches it as an image and you analyze it directly. For pure image analysis without loading it into your context, delegate to the `multimodal-looker` agent.
- Windows/workspaces: `hyprctl clients -j` (class, title, address, workspace, pid), `hyprctl activewindow -j`. `wmctrl -l` sees only XWayland windows — prefer hyprctl.

## 2. Understand the UI (AT-SPI accessibility tree)

```python
import pyatspi
desktop = pyatspi.Registry.getDesktop(0)          # running apps by name
for app in desktop:
    if app.name == "TARGET":                       # walk it recursively
        for child in app:
            print(child.getRoleName(), repr(child.name))
```

- Useful queries: `getRoleName()`, `name`, `getStates()`, `queryText().getText(0, -1)` (read text), `queryValue()` (read value), `queryAction().nActions` / `.doAction(i)` (activate/click/press/toggle a control), `querySelection()`.
- Electron/Chromium apps (Chrome, VS Code, Slack…) expose their tree only with accessibility forced on: restart with `--force-renderer-accessibility` or set it in the app's flags.
- Timeout a11y scripts (`timeout 15 python3 ...`); a stuck app must not hang the session.

## 3. Act (least invasive first)

1. Prefer **AT-SPI actions** (`doAction`) and **value sets** (`queryValue().currentValue = x`) — no synthetic input, works headless of focus.
2. Window management via hyprctl dispatchers: focus `hyprctl dispatch focuswindow address:0x…` (or `class:X` / `title:X`), switch `workspace N`, launch `exec APP`, close the focused window `killactive`, move/resize `movewindowpixel`/`resizewindowpixel`.
3. **No synthetic keyboard/mouse is installed** (no ydotool/wtype/xdotool). Raw typing/dragging is unavailable — use AT-SPI text/value interfaces, or clipboard via `wl-copy` + app paste handled through AT-SPI. If a task truly needs keystroke synthesis, tell the user and offer to install `ydotool` (+`ydotoold`); do not install it silently.
4. After acting, re-screenshot or re-query the tree to confirm the effect before reporting.

## Safety

- Look before asserting: never claim what an app shows or supports without a fresh screenshot/tree read; app state changes under you.
- Confirm with the user (`question` tool) before destructive or hard-to-reverse UI actions: deleting data, closing unsaved work, sending messages/mail, changing system settings.
- Never execute financial actions (trades, orders, transfers, payments) — ask the user to do those.
- Never read or enter credentials, secrets, or 2FA codes; do not interact with 1Password or keyring prompts beyond reporting they're blocking.
- Screenshots and UI trees can contain private data: analyze locally, never paste contents into external services or send to other agents unless the user asked.
- Links seen in apps: do not click through unknown URLs; surface the full URL and ask if it looks unfamiliar.
