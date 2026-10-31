#!/usr/bin/env bash
#
# completion-gate.sh — Stop hook (ADVISORY final-review gate)
#
# Fires when the MAIN agent is about to stop. If this session edited code and the
# working tree still has code changes, it nudges the agent ONCE to run a final
# `completion-reviewer` pass — then the agent decides for itself: rework the
# blockers, or judge them ad-hoc/acceptable and proceed.
#
# Advisory, not blocking: the nudge fires at most once per stop cycle. Claude sets
# `stop_hook_active` after a stop-hook continuation, so the *next* stop attempt is
# always allowed through regardless of the agent's choice — no marker/ticket state
# needed, and no infinite loop.
#
# Disable: remove the Stop entry in ~/.claude/settings.json.

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
j() { command -v jq >/dev/null 2>&1 && [ -n "$payload" ] && printf '%s' "$payload" | jq -r "$1" 2>/dev/null; }

# Already continued because of this hook → let the agent stop. The rework-vs-skip
# decision is theirs; we do not nag twice in one cycle.
[ "$(j '.stop_hook_active // false')" = "true" ] && exit 0

cwd="$(j '.cwd // empty')"; [ -z "$cwd" ] && cwd="$PWD"
cd "$cwd" 2>/dev/null || exit 0

# Only meaningful inside a git repo (need a diff to scope a review to).
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Did THIS session actually edit files? The transcript carries the tool calls;
# if it never used an edit tool, this was a read/discussion session → no gate.
tp="$(j '.transcript_path // empty')"
if [ -n "$tp" ] && [ -f "$tp" ]; then
  grep -qE '"name"[[:space:]]*:[[:space:]]*"(Edit|Write|MultiEdit|NotebookEdit)"' "$tp" 2>/dev/null || exit 0
fi

# Code changes left in the working tree (excluding tooling/noise paths)?
changes="$(git status --porcelain --no-renames 2>/dev/null \
  | sed -E 's/^.{3}//; s/^"(.*)"$/\1/' \
  | grep -vE '(^|/)(\.omc|\.serverless|\.git)/|\.log$')"
[ -z "$changes" ] && exit 0
count="$(printf '%s\n' "$changes" | grep -c .)"

# Advisory nudge — surface the final-review requirement; the MAIN agent decides.
{
  echo "🔍 Final review gate (advisory) — ${count} changed path(s) in the working tree before you stop."
  echo
  echo "Before ending this session, do a FINAL verification pass:"
  echo "  1. Spawn the 'completion-reviewer' subagent against the current changes."
  echo "  2. Read its VERDICT / BLOCKERS, then DECIDE — your call:"
  echo "       • REWORK  — blockers are real: fix them (or delegate the fix), then finish."
  echo "       • PROCEED — findings are ad-hoc / out-of-scope / acceptable for now:"
  echo "                   note why in one line and stop anyway."
  echo
  echo "This nudge fires once; your next stop goes through regardless of the choice."
} >&2
exit 2
