#!/usr/bin/env bash
# ~/.claude/hooks/forbidden-guard.sh
#
# 금지된 파일 접근 시 우회 시도 전 사용자 확인을 강제하는 PreToolUse 훅
#
# ✅ exit 2 = 하드 블록 → skipDangerousModePermissionPrompt: true 에도 작동
# ✅ Read / Write / Edit: 전체 패턴 매칭
# ✅ Bash: 실제 파일 읽기 명령(cat/head/tail/source/grep 등) 뒤 인수만 검사
#          → echo/printf 안의 문자열 참조는 오탐하지 않음
# ✅ ~/.claude/forbidden-patterns.txt 로 패턴 관리
# ✅ ~/.claude/.forbidden-allowlist 에 경로 추가 시 일시 허용

set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PATTERNS_FILE="${CONFIG_DIR}/forbidden-patterns.txt"
ALLOWLIST_FILE="${CONFIG_DIR}/.forbidden-allowlist"

TMP_INPUT=$(mktemp)
cat > "$TMP_INPUT"
trap 'rm -f "$TMP_INPUT"' EXIT

python3 - "$TMP_INPUT" "$PATTERNS_FILE" "$ALLOWLIST_FILE" <<'PYEOF'
import sys, json, fnmatch, os, re, shlex

input_file     = sys.argv[1]
patterns_file  = sys.argv[2]
allowlist_file = sys.argv[3]

# ── 입력 파싱 ──────────────────────────────────────────────────────────────
with open(input_file) as f:
    try:
        data = json.load(f)
    except Exception:
        sys.exit(0)

tool_name  = data.get('tool_name', '')
tool_input = data.get('tool_input', {})

# ── 패턴 로드 ──────────────────────────────────────────────────────────────
def load_lines(path):
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return [l.strip() for l in f if l.strip() and not l.startswith('#')]

def expand(p):
    return os.path.expanduser(p)

patterns  = [expand(p) for p in load_lines(patterns_file)]
allowlist = [expand(p) for p in load_lines(allowlist_file)]

if not patterns:
    sys.exit(0)

# ── 허용 목록 확인 ─────────────────────────────────────────────────────────
def in_allowlist(path):
    for a in allowlist:
        if path.startswith(a) or a.rstrip('/') in path:
            return True
    return False

# ── 패턴 매칭 (단일 경로) ──────────────────────────────────────────────────
def matches(path):
    for pat in patterns:
        if '*' in pat or '?' in pat:
            if fnmatch.fnmatch(os.path.basename(path), os.path.basename(pat)):
                return pat
            if fnmatch.fnmatch(path, pat):
                return pat
        else:
            if path.startswith(pat) or pat.rstrip('/') in path:
                return pat
    return None

# ── Bash: 실제 파일 읽기 명령 뒤 인수 추출 ────────────────────────────────
# echo/printf 같은 "출력" 명령 뒤의 경로는 무시
FILE_READ_CMDS = {
    'cat', 'head', 'tail', 'tac', 'less', 'more', 'bat',
    'grep', 'egrep', 'fgrep', 'rg', 'ag', 'awk', 'sed',
    'wc', 'sort', 'uniq', 'cut',
    'vim', 'vi', 'nano', 'emacs', 'view',
    'source', 'python', 'python3', 'node', 'ruby', 'perl',
    'openssl', 'ssh-keygen', 'gpg',
    'base64', 'xxd', 'hexdump', 'od',
    'cp', 'mv', 'ln', 'rsync', 'scp',
}

SAFE_CMDS = {'echo', 'printf', 'print', 'info', 'debug', 'warn', 'error'}

def extract_file_args_from_bash(cmd):
    """
    파일 읽기 명령 뒤의 경로 인수만 추출.
    echo/printf 뒤는 건너뜀.
    입력 리다이렉션 (< file) 도 검사.
    """
    candidates = set()

    # 입력 리다이렉션: < file
    for m in re.finditer(r'<\s*([^\s|&;>]+)', cmd):
        candidates.add(os.path.expanduser(m.group(1)))

    # 파이프/세미콜론/&&/|| 로 분리된 서브커맨드별 처리
    sub_cmds = re.split(r'[|;&]|&&|\|\|', cmd)
    for sub in sub_cmds:
        sub = sub.strip()
        if not sub:
            continue
        try:
            tokens = shlex.split(sub)
        except ValueError:
            tokens = sub.split()

        if not tokens:
            continue

        base_cmd = os.path.basename(tokens[0])

        # safe 명령(echo 등) 뒤 → 건너뜀
        if base_cmd in SAFE_CMDS:
            continue

        # 파일 읽기 명령이거나, 플래그(-x) 가 아닌 경로처럼 생긴 인수
        is_file_cmd = base_cmd in FILE_READ_CMDS

        HOME = os.path.expanduser('~')
        for tok in tokens[1:]:
            if tok.startswith('-'):
                continue
            expanded = os.path.expanduser(tok)
            # 실제 파일시스템 경로처럼 시작하는 토큰만 허용
            # (인라인 스크립트, JSON 문자열 등 오탐 방지)
            is_path_like = (
                expanded.startswith('/') or
                expanded.startswith(HOME + '/') or
                expanded.startswith('./') or
                expanded.startswith('../')
            )
            if is_file_cmd and is_path_like:
                candidates.add(expanded)

    return candidates

# ── 블록 메시지 ────────────────────────────────────────────────────────────
def block(file_path, pattern, tool):
    print(f"🚫 [forbidden-guard] 접근 차단 — {tool} → {file_path}")
    print(f"   매칭 패턴: {pattern}")
    print()
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("이 파일은 forbidden-patterns.txt 에 의해 접근이 금지되어 있습니다.")
    print("우회 방법(cat, head, grep, Bash 등)을 시도하기 전에")
    print("반드시 사용자에게 먼저 물어보세요.")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()
    print("▶ Claude에게 지시: 사용자에게 다음과 같이 물어볼 것:")
    print(f'  "「{file_path}」파일에 접근하려 합니다.')
    print( '   우회 방법을 시도해도 될까요?"')
    print()
    print(f"▶ 사용자가 허용하면 → 아래를 실행하고 재시도:")
    print(f"  echo '{file_path}' >> {allowlist_file}")
    print()
    print("▶ --dangerously-skip-permissions / skipDangerousModePermissionPrompt")
    print("  모드에서도 이 블록은 동일하게 적용됩니다. (exit 2)")
    sys.exit(2)

# ── 메인 분기 ─────────────────────────────────────────────────────────────
if tool_name in ('Read', 'Write', 'Edit'):
    path = tool_input.get('file_path') or tool_input.get('path', '')
    if path:
        path = os.path.expanduser(path)
        if not in_allowlist(path):
            pat = matches(path)
            if pat:
                block(path, pat, tool_name)

elif tool_name == 'Bash':
    cmd = tool_input.get('command', '')
    for candidate in extract_file_args_from_bash(cmd):
        if in_allowlist(candidate):
            continue
        pat = matches(candidate)
        if pat:
            block(candidate, pat, 'Bash')

sys.exit(0)
PYEOF
