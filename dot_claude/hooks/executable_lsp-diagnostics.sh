#!/usr/bin/env bash
#
# lsp-diagnostics.sh — SubagentStop hook
#
# After a subagent (Task) finishes, detect the files it changed in the repo and
# run the appropriate static checker for each language. If any check fails, exit
# with code 2 so Claude Code feeds the diagnostics back into the agent and forces
# it to fix the problems before declaring the work done.
#
# Languages: TypeScript (tsc), Python (ruff + mypy), JS/TS (eslint),
#            Go (go vet), bash (shellcheck + bash -n), terraform (fmt -check).
#
# Each checker only runs when (a) a matching file changed AND (b) the tool is
# available. Missing tools are skipped silently (with a one-line note on stderr).

set -uo pipefail

# ---------------------------------------------------------------------------
# Resolve working directory from the hook payload (stdin JSON), fall back to PWD
# ---------------------------------------------------------------------------
payload="$(cat 2>/dev/null || true)"
cwd=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
fi
[ -z "$cwd" ] && cwd="$PWD"
cd "$cwd" 2>/dev/null || cd "$PWD" || exit 0

# ---------------------------------------------------------------------------
# Two modes, decided by the payload:
#   • PostToolUse (Edit|Write): payload carries tool_input.file_path → check
#     just that one file. Fast, fires per edit (main agent).
#   • SubagentStop: check only the files THIS subagent edited, read from its
#     transcript (agent_transcript_path). A read-only subagent edited nothing →
#     allow stop; it can't fix other sessions' changes and blocking it only
#     replaces its report with hook replies. No transcript → fall back to git.
# ---------------------------------------------------------------------------
pj() { command -v jq >/dev/null 2>&1 && [ -n "$payload" ] && printf '%s' "$payload" | jq -r "$1" 2>/dev/null; }
edited_file="$(pj '.tool_input.file_path // empty')"
agent_transcript="$(pj '.agent_transcript_path // empty')"
# Already continuing because a stop hook blocked once → report but never block again (no hook loops).
stop_hook_active="$(pj '.stop_hook_active // false')"

if [ -n "$edited_file" ]; then
  # PostToolUse single-file mode — no git scoping needed.
  [ -f "$edited_file" ] || exit 0          # deleted / not a real file → nothing to check
  CHANGED=("$edited_file")
elif [ -n "$agent_transcript" ] && [ -r "$agent_transcript" ]; then
  # ponytail: files changed via Bash (sed, heredoc) are not in tool_use inputs and go unchecked.
  mapfile -t CHANGED < <(jq -r 'select(.type=="assistant") | .message.content[]?
      | select(.type=="tool_use" and (.name|test("^(Edit|Write|MultiEdit|NotebookEdit)$")))
      | .input.file_path // .input.notebook_path // empty' "$agent_transcript" 2>/dev/null | sort -u)
else
  # SubagentStop without a transcript — not a git repo? Nothing to scope to; allow stop.
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
  mapfile -t CHANGED < <(git status --porcelain --no-renames 2>/dev/null \
    | sed -E 's/^.{3}//' \
    | sed -E 's/^"(.*)"$/\1/' \
    | sort -u)
fi

[ "${#CHANGED[@]}" -eq 0 ] && exit 0

ts_files=();  py_files=();  go_files=();  sh_files=();  tf_files=();  lint_files=()
for f in "${CHANGED[@]}"; do
  [ -f "$f" ] || continue            # skip deletions / dirs
  case "$f" in
    *.ts|*.tsx)      ts_files+=("$f"); lint_files+=("$f") ;;
    *.js|*.jsx|*.mjs|*.cjs) lint_files+=("$f") ;;
    *.py)            py_files+=("$f") ;;
    *.go)            go_files+=("$f") ;;
    *.sh|*.bash)     sh_files+=("$f") ;;
    *.tf|*.tfvars)   tf_files+=("$f") ;;
  esac
done

REPORT=""
FAILED=0
have() { command -v "$1" >/dev/null 2>&1; }
# Nearest ancestor dir of $1 (a file or dir) that contains $2. Monorepos keep node_modules / tsconfig per package,
# so tools must run from the package that owns the file — never a global binary (`npx --no-install` falls back to a
# globally installed eslint whose major can differ from the project's and crash on its plugins).
find_up() {
  local dir
  if [ -d "$1" ]; then dir="$(cd "$1" && pwd)"; else dir="$(cd "$(dirname "$1")" 2>/dev/null && pwd)"; fi || return 1
  while [ -n "$dir" ]; do
    [ -e "$dir/$2" ] && { printf '%s\n' "$dir"; return 0; }
    [ "$dir" = "/" ] && break
    dir="$(dirname "$dir")"
  done
  return 1
}
abspath() { case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$cwd/$1" ;; esac; }
# A linter crash (config/plugin/version problem) is the tool's fault, not the change's — skip, don't block.
tool_crashed() { printf '%s' "$1" | grep -qE "Oops! Something went wrong|Error while loading rule|Cannot find module|couldn't find an eslint\.config|No ESLint configuration found"; }
add_fail() { REPORT+="$1"$'\n'; FAILED=1; }

# ---------------------------------------------------------------------------
# bash — shellcheck + syntax check
# ---------------------------------------------------------------------------
if [ "${#sh_files[@]}" -gt 0 ]; then
  for f in "${sh_files[@]}"; do
    if out="$(bash -n "$f" 2>&1)"; then :; else
      add_fail "❌ bash -n ($f):"$'\n'"$out"
    fi
  done
  if have shellcheck; then
    if out="$(shellcheck -S warning "${sh_files[@]}" 2>&1)"; then :; else
      add_fail "❌ shellcheck:"$'\n'"$out"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# terraform — fmt (no init), then validate + tflint per changed directory.
# validate/tflint need an initialized dir; uninitialized dirs are skipped (pass).
# ---------------------------------------------------------------------------
if [ "${#tf_files[@]}" -gt 0 ]; then
  # Resolve a Terraform binary: prefer terraform, fall back to tofu.
  tf_bin=""
  if have terraform; then tf_bin="terraform"; elif have tofu; then tf_bin="tofu"; fi

  # fmt — operates on files directly, no init required.
  if [ -n "$tf_bin" ]; then
    if out="$("$tf_bin" fmt -check -diff "${tf_files[@]}" 2>&1)"; then :; else
      add_fail "❌ terraform fmt (run: $tf_bin fmt):"$'\n'"$out"
    fi
  fi

  # Unique directories owning the changed .tf/.tfvars files.
  mapfile -t tf_dirs < <(printf '%s\n' "${tf_files[@]}" | xargs -r -n1 dirname | sort -u)

  for d in "${tf_dirs[@]}"; do
    # validate — needs an initialized dir. Skip (pass) when not init'd.
    if [ -n "$tf_bin" ]; then
      if [ -d "$d/.terraform" ]; then
        if out="$(cd "$d" && "$tf_bin" validate -no-color 2>&1)"; then :; else
          if printf '%s' "$out" | grep -qiE "terraform init|not been initialized|Module not installed|Missing required provider|please run"; then
            REPORT+="ℹ️  $d not fully initialized — skipped validate"$'\n'
          else
            add_fail "❌ terraform validate ($d):"$'\n'"$out"
          fi
        fi
      else
        REPORT+="ℹ️  $d not initialized (no .terraform) — skipped validate"$'\n'
      fi
    fi

    # tflint — only when installed; skip (pass) when its plugins aren't init'd.
    if have tflint; then
      if out="$(cd "$d" && tflint --no-color 2>&1)"; then :; else
        if printf '%s' "$out" | grep -qiE "tflint --init|plugin.*not installed|not initialized|Failed to initialize"; then
          REPORT+="ℹ️  tflint not initialized for $d (run: tflint --init) — skipped"$'\n'
        else
          add_fail "❌ tflint ($d):"$'\n'"$out"
        fi
      fi
    fi
  done

  have tflint || REPORT+="ℹ️  tflint not installed — skipped Terraform lint"$'\n'
fi

# ---------------------------------------------------------------------------
# Go — go vet on the packages owning changed files
#
# This may be a multi-module repo (no go.mod/go.work at $cwd), so `go vet`
# must run from each changed file's own module root, not from $cwd. For each
# changed file, walk up to the nearest go.mod, then run `go vet ./...` once
# per unique module root discovered.
# ---------------------------------------------------------------------------
if [ "${#go_files[@]}" -gt 0 ] && have go; then
  find_module_root() {
    local dir
    dir="$(cd "$(dirname "$1")" 2>/dev/null && pwd)" || return 1
    while [ -n "$dir" ]; do
      if [ -f "$dir/go.mod" ]; then
        printf '%s\n' "$dir"
        return 0
      fi
      [ "$dir" = "/" ] && break
      dir="$(dirname "$dir")"
    done
    return 1
  }
  declare -A seen_mod_roots=()
  go_mod_roots=()
  for f in "${go_files[@]}"; do
    if root="$(find_module_root "$f")"; then
      if [ -z "${seen_mod_roots[$root]:-}" ]; then
        seen_mod_roots[$root]=1
        go_mod_roots+=("$root")
      fi
    fi
  done
  for root in "${go_mod_roots[@]}"; do
    if out="$(cd "$root" && go vet ./... 2>&1)"; then :; else
      add_fail "❌ go vet ($root):"$'\n'"$out"
    fi
  done
  no_mod=0
  for f in "${go_files[@]}"; do
    find_module_root "$f" >/dev/null 2>&1 || no_mod=1
  done
  [ "$no_mod" -eq 1 ] && REPORT+="ℹ️  go vet: some changed .go files have no go.mod ancestor — skipped"$'\n'
fi

# ---------------------------------------------------------------------------
# Python — ruff then mypy (each only if installed)
# ---------------------------------------------------------------------------
if [ "${#py_files[@]}" -gt 0 ]; then
  if have ruff; then
    if out="$(ruff check "${py_files[@]}" 2>&1)"; then :; else
      add_fail "❌ ruff:"$'\n'"$out"
    fi
  else
    REPORT+="ℹ️  ruff not installed — skipped Python lint"$'\n'
  fi
  if have mypy; then
    if out="$(mypy "${py_files[@]}" 2>&1)"; then :; else
      add_fail "❌ mypy:"$'\n'"$out"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# TypeScript — tsc --noEmit once at project root (per-file tsc is unreliable)
# ---------------------------------------------------------------------------
if [ "${#ts_files[@]}" -gt 0 ]; then
  declare -A seen_ts=()
  for f in "${ts_files[@]}"; do
    proj="$(find_up "$(abspath "$f")" tsconfig.json)" || { REPORT+="ℹ️  no tsconfig.json for $f — skipped TS type-check"$'\n'; continue; }
    [ -n "${seen_ts[$proj]:-}" ] && continue
    seen_ts[$proj]=1
    pkg="$(find_up "$proj" node_modules/.bin/tsc)" || { REPORT+="ℹ️  no local tsc for $proj (install deps) — skipped"$'\n'; continue; }
    if out="$(cd "$proj" && "$pkg/node_modules/.bin/tsc" --noEmit -p . 2>&1)"; then :; else
      add_fail "❌ tsc --noEmit ($proj):"$'\n'"$out"
    fi
  done
fi

# ---------------------------------------------------------------------------
# ESLint — on changed JS/TS files
# ---------------------------------------------------------------------------
if [ "${#lint_files[@]}" -gt 0 ]; then
  # Group files by the package whose local eslint owns them; run each group from that package.
  declare -A lint_groups=()
  for f in "${lint_files[@]}"; do
    a="$(abspath "$f")"
    if pkg="$(find_up "$a" node_modules/.bin/eslint)"; then
      lint_groups[$pkg]+="$a"$'\n'
    fi
  done
  for pkg in "${!lint_groups[@]}"; do
    mapfile -t group < <(printf '%s' "${lint_groups[$pkg]}" | sed '/^$/d')
    if out="$(cd "$pkg" && node_modules/.bin/eslint "${group[@]}" 2>&1)"; then :; else
      if tool_crashed "$out"; then
        REPORT+="ℹ️  eslint ($pkg) crashed or has no config — skipped: $(printf '%s' "$out" | grep -m1 -E 'Error|Oops|config')"$'\n'
      else
        add_fail "❌ eslint ($pkg):"$'\n'"$out"
      fi
    fi
  done
fi

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
if [ "$FAILED" -eq 1 ] && [ "$stop_hook_active" = "true" ] && [ -z "$edited_file" ]; then
  # Second stop after a block: surface the problems but let the agent finish (its report must survive).
  { echo "⚠️  Static analysis still reports problems (not blocking a second time):"; printf '%s' "$REPORT"; } >&2
  exit 0
fi
if [ "$FAILED" -eq 1 ]; then
  {
    echo "🛑 Static analysis found problems in files changed by the subagent."
    echo "   Fix every issue below, then continue. Do NOT stop with these unresolved."
    echo "-----------------------------------------------------------------------"
    printf '%s' "$REPORT"
  } >&2
  exit 2
fi

# Surface informational skips (non-blocking) and allow stop.
[ -n "$REPORT" ] && printf '%s' "$REPORT" >&2
exit 0
