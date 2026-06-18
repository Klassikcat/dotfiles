#!/usr/bin/env bash
# ~/.claude/hooks/destroy-guard.sh
#
# terraform / terragrunt 의 파괴(destroy) 명령을 "어떤 형태로든" 차단하는 PreToolUse 훅
#
# ✅ exit 2 = 하드 블록 → skipDangerousModePermissionPrompt: true 에도 작동
# ✅ 우회 경로 커버:
#     - AWS_PROFILE=x terraform destroy   (env var prefix)
#     - env terraform destroy
#     - cd infra && terraform destroy     (세미콜론/&&/|| 분리)
#     - bash -c "terraform destroy"        (따옴표 내부 문자열도 그대로 부분매칭)
#     - terraform -chdir=infra destroy
#     - terragrunt destroy / terragrunt run-all destroy / terragrunt --all destroy
#     - terraform apply -destroy / terraform plan -destroy   (-destroy 플래그)
# ✅ 오탐 방지: `terraform plan -out=destroy.tfplan` 같은 건 차단하지 않음
# ✅ ~/.claude/.destroy-allowlist 에 토큰을 추가하면 해당 세션에서 일시 허용
#    (라인 단위 substring 매칭 — 예: 특정 워크스페이스명/디렉터리)

set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ALLOWLIST_FILE="${CONFIG_DIR}/.destroy-allowlist"

TMP_INPUT=$(mktemp)
cat > "$TMP_INPUT"
trap 'rm -f "$TMP_INPUT"' EXIT

python3 - "$TMP_INPUT" "$ALLOWLIST_FILE" <<'PYEOF'
import sys, json, os, re

input_file     = sys.argv[1]
allowlist_file = sys.argv[2]

with open(input_file) as f:
    try:
        data = json.load(f)
    except Exception:
        sys.exit(0)

if data.get('tool_name', '') != 'Bash':
    sys.exit(0)

cmd = (data.get('tool_input', {}) or {}).get('command', '') or ''
if not cmd:
    sys.exit(0)

# ── 일시 허용 목록 (라인 substring 매칭) ──────────────────────────────────
def load_lines(path):
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return [l.strip() for l in f if l.strip() and not l.startswith('#')]

for allow in load_lines(allowlist_file):
    if allow in cmd:
        sys.exit(0)

# ── destroy 탐지 ─────────────────────────────────────────────────────────
# 1) destroy 서브커맨드:  terraform [global flags / run-all / --all] destroy
SUBCMD = re.compile(
    r'\bterra(?:form|grunt)\b'
    r'(?:\s+(?:-{1,2}[^\s]+|run-all|--all))*'   # -chdir=.. , run-all, --all 등 destroy 앞 토큰
    r'\s+destroy\b'
)

# 2) -destroy 플래그:  terraform apply -destroy / terraform plan -destroy
FLAG = re.compile(
    r'\bterra(?:form|grunt)\b[^|;&\n]*?\s-{1,2}destroy\b'
)

m = SUBCMD.search(cmd) or FLAG.search(cmd)
if not m:
    sys.exit(0)

# ── 블록 ──────────────────────────────────────────────────────────────────
def err(s=""):
    print(s, file=sys.stderr)

matched = m.group(0).strip()
err("🚫 [destroy-guard] terraform/terragrunt destroy 명령이 차단되었습니다.")
err(f"   감지된 부분: {matched}")
err()
err("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
err("인프라 파괴(destroy) 명령은 안전장치로 금지되어 있습니다.")
err("env-var prefix / cd && / bash -c 등 우회 형태도 모두 차단됩니다.")
err("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
err()
err("▶ Claude에게 지시: 실행하지 말고 먼저 사용자에게 확인할 것.")
err("▶ 정말 필요하면 사용자가 직접 터미널에서 실행하거나,")
err(f"  아래처럼 허용 토큰을 추가한 뒤 재시도:")
err(f"  echo '<명령에 포함된 고유 문자열>' >> {allowlist_file}")
err()
err("▶ skipDangerousModePermissionPrompt 모드에서도 동일하게 적용됩니다. (exit 2)")
sys.exit(2)
PYEOF
