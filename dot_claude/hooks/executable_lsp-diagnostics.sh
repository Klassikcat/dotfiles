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
#   • SubagentStop: no file_path → scope to every file changed in the working
#     tree via git. Broad, fires once when a subagent finishes.
# ---------------------------------------------------------------------------
edited_file=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  edited_file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
fi

if [ -n "$edited_file" ]; then
  # PostToolUse single-file mode — no git scoping needed.
  [ -f "$edited_file" ] || exit 0          # deleted / not a real file → nothing to check
  CHANGED=("$edited_file")
else
  # SubagentStop mode — not a git repo? Nothing to scope to; allow stop.
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
# Resolve a JS tool: prefer project-local node_modules/.bin, else npx --no-install
js_bin() {
  local name="$1"
  if [ -x "node_modules/.bin/$name" ]; then echo "node_modules/.bin/$name"; return 0; fi
  if have npx; then echo "npx --no-install $name"; return 0; fi
  return 1
}
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
# ---------------------------------------------------------------------------
if [ "${#go_files[@]}" -gt 0 ] && have go; then
  mapfile -t go_dirs < <(printf '%s\n' "${go_files[@]}" | xargs -r -n1 dirname | sort -u | sed 's#^#./#')
  if out="$(go vet "${go_dirs[@]}" 2>&1)"; then :; else
    add_fail "❌ go vet:"$'\n'"$out"
  fi
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
  if [ -f tsconfig.json ] && tsc_cmd="$(js_bin tsc)"; then
    if out="$($tsc_cmd --noEmit 2>&1)"; then :; else
      add_fail "❌ tsc --noEmit:"$'\n'"$out"
    fi
  else
    REPORT+="ℹ️  tsc/tsconfig.json not found — skipped TS type-check"$'\n'
  fi
fi

# ---------------------------------------------------------------------------
# ESLint — on changed JS/TS files
# ---------------------------------------------------------------------------
if [ "${#lint_files[@]}" -gt 0 ]; then
  if eslint_cmd="$(js_bin eslint)"; then
    if out="$($eslint_cmd "${lint_files[@]}" 2>&1)"; then :; else
      add_fail "❌ eslint:"$'\n'"$out"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
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
