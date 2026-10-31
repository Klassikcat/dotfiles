#!/usr/bin/env bash
# ~/.claude/hooks/kube-context-guard.sh
#
# kubectl/helm/k9s 등 쿠버네티스 명령 실행 전 컨텍스트 안전 가드 (PreToolUse, Bash)
#
# 위험도 기반:
#   - 쓰기 명령(delete/apply/scale/exec/…)  : --context 없으면 BLOCK
#   - prod 컨텍스트(또는 확인 불가)          : 읽기여도 --context 없으면 BLOCK
#   - 비-prod 읽기                           : PASS + 현재 컨텍스트 리마인더 주입
#   - 컨텍스트 전환 도구(kubectx/kubens/k9s) : PASS + 리마인더 (비차단)
# exit 2 = 하드 블록(skipDangerousModePermissionPrompt 에도 작동)
# 우회 커버: env-var prefix / cd && / bash -c "..." / 래퍼(sudo/xargs/timeout/watch) /
#            개행 결합 / 루프·조건문(for…do, if…then) / 풀경로(/usr/bin/kubectl)
# prod 패턴:   ~/.claude/.kube-prod-contexts
# 임시 허용:   echo '<토큰>' >> ~/.claude/.kube-context-allowlist
set -euo pipefail
CONFIG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROD_FILE="${CONFIG_DIR}/.kube-prod-contexts"
ALLOWLIST_FILE="${CONFIG_DIR}/.kube-context-allowlist"
TMP_INPUT=$(mktemp); cat > "$TMP_INPUT"; trap 'rm -f "$TMP_INPUT"' EXIT
python3 - "$TMP_INPUT" "$PROD_FILE" "$ALLOWLIST_FILE" <<'PYEOF'
import sys, json, os, re, shlex, subprocess

input_file, prod_file, allow_file = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.load(open(input_file))
except Exception:
    sys.exit(0)
if data.get('tool_name') != 'Bash':
    sys.exit(0)
cmd = (data.get('tool_input', {}) or {}).get('command', '') or ''
if not cmd:
    sys.exit(0)

KUBE_TOOLS = ('kubectl', 'helm', 'kubectx', 'kubens', 'k9s')
# 래퍼 명령: 뒤따르는 kube 도구를 찾아 재검사 (sudo/xargs/timeout/watch …)
WRAPPERS = {'sudo', 'xargs', 'time', 'timeout', 'watch', 'nohup',
            'nice', 'stdbuf', 'ionice', 'command'}
# 선행 셸 제어 키워드 (for…do kubectl / if kubectl / while…do 우회 방지)
SHELL_KW = {'if', 'then', 'else', 'elif', 'fi', 'do', 'done', 'while',
            'until', 'for', 'case', 'esac', '{', '}', '!'}
# 빠른 경로: 쿠버네티스 도구 미포함이면 즉시 통과 (subprocess 비용 0)
if not any(t in cmd for t in KUBE_TOOLS):
    sys.exit(0)

def load_lines(path):
    if not os.path.exists(path):
        return []
    return [l.strip() for l in open(path) if l.strip() and not l.startswith('#')]

# 임시 허용 (substring)
for a in load_lines(allow_file):
    if a in cmd:
        sys.exit(0)

PROD_DEFAULT = ['prod', 'mildangEksCluster', 'aidt-global-eks',
                ':345283705682:', ':530467656283:', 'nks_kr_mildang-prod']
PROD_PATTERNS = load_lines(prod_file) or PROD_DEFAULT

READ_VERBS = {'get','describe','logs','log','top','explain','api-resources',
              'api-versions','cluster-info','version','wait','events','diff','auth'}
WRITE_VERBS = {'delete','apply','create','replace','patch','edit','scale','autoscale',
               'rollout','drain','cordon','uncordon','taint','set','expose','run',
               'exec','cp','attach','debug','evict','annotate','label'}
HELM_WRITE = {'install','upgrade','uninstall','delete','rollback'}
# 값을 받는 전역 플래그 (verb 탐색 시 값 토큰 건너뛰기용)
VALUE_FLAGS = {'--context','-n','--namespace','--kubeconfig','--cluster','--user',
               '--server','--as','--as-group','--token','--cache-dir',
               '--request-timeout','--chunk-size','--kube-context'}

_cur_cache = {}
def current_context(env_extra=None, kubeconfig_flag=None):
    # KUBECONFIG/--kubeconfig 별로 컨텍스트가 다르므로 캐시 키로 사용
    key = kubeconfig_flag or (env_extra or {}).get('KUBECONFIG') or '__default__'
    if key in _cur_cache:
        return _cur_cache[key]
    env = dict(os.environ)
    if env_extra:
        env.update(env_extra)
    args = ['kubectl', 'config', 'current-context']
    if kubeconfig_flag:
        args = ['kubectl', '--kubeconfig', kubeconfig_flag, 'config', 'current-context']
    try:
        out = subprocess.run(args, capture_output=True, text=True, timeout=5, env=env)
        val = out.stdout.strip() if out.returncode == 0 else ''
    except Exception:
        val = ''
    _cur_cache[key] = val
    return val

def is_prod(ctx):
    if not ctx:
        return True  # 확인 불가 → 위험으로 간주 (fail-safe)
    return any(p in ctx for p in PROD_PATTERNS)

def split_subcommands(s):
    # 파이프/세미콜론/&&/||/백그라운드 + 개행까지 분리 (개행 우회 방지)
    return re.split(r'\|\||&&|[|;&\n\r]', s)

def strip_env_prefix(tokens):
    """선행 셸 키워드/VAR=val/env 토큰 제거, KUBECONFIG 추출."""
    env_extra = {}
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if t in SHELL_KW or t == 'env':
            i += 1; continue
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$', t)
        if m:
            env_extra[m.group(1)] = m.group(2)
            i += 1; continue
        break
    return tokens[i:], env_extra

def has_context_flag(tokens, names):
    for t in tokens:
        for n in names:
            if t == n or t.startswith(n + '='):
                return True
    return False

def kubeconfig_from(tokens, env_extra):
    if 'KUBECONFIG' in env_extra:
        return env_extra['KUBECONFIG']
    for i, t in enumerate(tokens):
        if t == '--kubeconfig' and i + 1 < len(tokens):
            return tokens[i+1]
        if t.startswith('--kubeconfig='):
            return t.split('=', 1)[1]
    return None

def find_verb(tokens_after_tool):
    i = 0
    toks = tokens_after_tool
    while i < len(toks):
        t = toks[i]
        if t in VALUE_FLAGS:
            i += 2; continue
        if t.startswith('--') and '=' in t:
            i += 1; continue
        if t.startswith('-'):
            i += 1; continue
        return t
    return None

def block(tool, verb, ctx, prod):
    e = sys.stderr.write
    e("🚫 [kube-context-guard] --context 미지정 쿠버네티스 명령이 차단되었습니다.\n")
    e(f"   도구: {tool}   동작: {verb or '(알수없음)'}\n")
    e(f"   현재 컨텍스트: {ctx or '(확인불가)'}   prod/위험: {'예' if prod else '아니오'}\n")
    e("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    e("▶ 실행 전 컨텍스트를 명시적으로 확정하세요:\n")
    e("  1) 사용자가 컨텍스트를 지정했으면(prod/stage/dev 등)\n")
    e("     → 해당 --context=<ARN> (helm은 --kube-context=<ARN>) 를 붙여 재실행\n")
    e("  2) 사용자가 '현 컨텍스트/current context'라고 했으면\n")
    e(f"     → --context={ctx or '<현재컨텍스트>'} 를 붙여 재실행\n")
    e("  3) 사용자가 컨텍스트를 지정하지 않았고 대화에도 명시가 없으면\n")
    e("     → 실행하지 말고 AskUserQuestion 으로 '어느 컨텍스트에서 실행할까요?'\n")
    e("       (kubectl config get-contexts 목록을 제시) 라고 물어볼 것\n")
    e("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    e(f"▶ 임시 허용: echo '<명령 고유 토큰>' >> {allow_file}\n")
    e("▶ exit 2 — skipDangerousModePermissionPrompt 에서도 동일 적용\n")
    sys.exit(2)

def remind(msg):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse", "additionalContext": msg}}))
    sys.exit(0)

def analyze(tokens, depth=0):
    if depth > 3 or not tokens:
        return
    tokens, env_extra = strip_env_prefix(tokens)
    if not tokens:
        return
    base = os.path.basename(tokens[0])

    # bash -c "..." 재귀
    if base in ('bash', 'sh', 'zsh') and '-c' in tokens:
        idx = tokens.index('-c')
        if idx + 1 < len(tokens):
            for sub in split_subcommands(tokens[idx+1]):
                try:
                    analyze(shlex.split(sub), depth+1)
                except ValueError:
                    analyze(sub.split(), depth+1)
        return

    # 래퍼(sudo/xargs/timeout/watch …) → 뒤따르는 첫 kube 도구부터 재검사
    if base in WRAPPERS:
        for j in range(1, len(tokens)):
            if os.path.basename(tokens[j]) in KUBE_TOOLS:
                analyze(tokens[j:], depth+1)
                return
        return

    if base not in KUBE_TOOLS:
        return

    rest = tokens[1:]
    kcfg = kubeconfig_from(rest, env_extra)
    ctx = current_context(env_extra, kcfg)
    prod = is_prod(ctx)

    if base in ('kubectx', 'kubens'):
        remind(f"ℹ️ 컨텍스트/네임스페이스 전환 감지({base}). 이후 명령의 대상 컨텍스트가 바뀝니다. 현재: {ctx or '(확인불가)'}")
    if base == 'k9s':
        if has_context_flag(rest, ('--context',)):
            return
        remind(f"ℹ️ k9s 실행 — 현재 컨텍스트: {ctx or '(확인불가)'}. 의도한 클러스터가 맞는지 확인하세요.")

    if base == 'helm':
        if has_context_flag(rest, ('--kube-context',)):
            return
        verb = find_verb(rest)
        if verb in HELM_WRITE:
            block('helm', verb, ctx, prod)
        if prod:
            block('helm', verb, ctx, prod)
        remind(f"ℹ️ 현재 kube 컨텍스트: {ctx or '(확인불가)'} (helm read). 의도한 컨텍스트가 맞는지 확인하세요.")

    # kubectl
    if has_context_flag(rest, ('--context',)):
        return
    verb = find_verb(rest)
    if verb == 'config':
        return  # current-context/get-contexts/view/use-context 등 조회·전환은 통과
    if verb == 'version':
        return
    write = (verb in WRITE_VERBS) or (verb is not None and verb not in READ_VERBS)
    if write:
        block('kubectl', verb, ctx, prod)
    # kubectl read
    if prod:
        block('kubectl', verb, ctx, prod)
    remind(f"ℹ️ 현재 kubectl 컨텍스트: {ctx or '(확인불가)'} ({verb}). 의도한 컨텍스트가 맞는지 확인하세요.")

for sub in split_subcommands(cmd):
    sub = sub.strip()
    if not sub:
        continue
    try:
        toks = shlex.split(sub)
    except ValueError:
        toks = sub.split()
    analyze(toks)

sys.exit(0)
PYEOF
