#!/usr/bin/env bash
# Block until swww-daemon knows every output's current logical size, then exit 0.
# Hyprland emits monitor.layout_changed before the daemon's layer surfaces get their new
# configure, so an immediate `swww img` paints with the old size (stretched on rotation).
# Exits 1 after ~5s if the sizes never converge (e.g. daemon not running); caller still paints.

expected() {
    hyprctl monitors -j | jq -r '.[] | . as $m | (
        if (.transform % 2) == 1 then [.height, .width] else [.width, .height] end
        | map(. / $m.scale | round)) | "\($m.name) \(.[0])x\(.[1])"'
}

actual() {
    swww query 2>/dev/null | sed -nE 's/^: ([^:]+): ([0-9]+x[0-9]+),.*/\1 \2/p'
}

want=$(expected | sort)
for _ in $(seq 100); do
    [ "$(actual | sort)" = "$want" ] && exit 0
    sleep 0.05
done
exit 1
