#!/usr/bin/env bash
set -euo pipefail
runtime=$(mktemp -d)
trap 'rm -rf "$runtime"' EXIT
export XDG_RUNTIME_DIR=$runtime
export PAN_TEST_LOG=$runtime/events
script="$(dirname "$0")/MiddlePan.sh"
hyprctl() {
    printf '%s\n' "$3" >> "$PAN_TEST_LOG"
    printf '%s\n' "${PAN_TEST_REPLY:-ok}"
}
export -f hyprctl
bash "$script" down
bash "$script" up
expected=$', SPACE, down, active\n, mouse:273, down, active\n, mouse:273, up, active\n, SPACE, up, active'
[[ $(< "$PAN_TEST_LOG") == "$expected" ]]
# hyprctl may exit zero even when the dispatcher reports failure.
if PAN_TEST_REPLY='sendkeystate: invalid args' bash "$script" up 2>/dev/null; then
    echo 'FAIL: dispatcher failure was ignored' >&2
    exit 1
fi
echo 'PASS: input order, explicit target, and dispatcher error handling'
