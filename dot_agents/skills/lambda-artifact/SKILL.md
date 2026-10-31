---
name: lambda-artifact
description: Build a Lambda function, Lambda@Edge or Lambda Layer zip locally and send it to ARONA (wikiwiki provision agent) over A2A with `wikk agent send --lambda-artifact`. Use when a resource request needs Lambda code deployed — a new function/Edge function/Layer, or replacing the code of an ARONA-managed function or layer. Not available in the web chat.
---

# Lambda 코드 (함수·Lambda@Edge·Layer) via A2A

ARONA 는 코드를 실행하거나 수정하지 않는다. 너(로컬 코딩 에이전트)가 zip 을 만들고 테스트한다. ARONA 는 zip 을 정적으로만 검사(크기·경로·handler 파일·런타임·Layer 구조)해 통과한 것만 세션에 저장하고, 요청이 승인되면 그 zip 을 대상 계정·리전 코드 버킷으로 복사해 SAM `CodeUri` 로 배포한다. 승인은 기존 규칙을 따른다(코드라서 붙는 별도 규칙은 없다).

- **웹에서는 지원되지 않는다.** 웹 대화는 코드 배포 요청에 "웹에서는 아직 지원되지 않습니다"라고 답한다. 업로드는 A2A(`wikk agent send`)로만 된다.
- **zip 안 시크릿은 검사하지 않는다.** `.env`, 키 파일, 자격 증명, `node_modules/.cache` 같은 것을 넣지 말 것. zip 은 대상 계정 코드 버킷에 그대로 복사된다.
- 범위: 새 함수·Edge·Layer 생성, ARONA 가 관리하는(세션 팀 소유) 함수·Layer 의 코드 교체. 외부·다른 도구·다른 팀이 관리하는 함수는 기존 거절 규칙대로 거절된다.

## 1. zip 만들기

런타임은 `nodejs22.x`, `python3.13` 만 된다. zip 은 50MB(압축 해제 총량 250MB, 엔트리 10,000개, 엔트리별 압축률 100배) 이하. 심볼릭 링크, `..`·절대경로·백슬래시 경로, 중복 엔트리는 거절된다.

함수·Edge: handler 파일이 **zip 루트**(또는 handler 에 적은 경로)에 있어야 한다. nodejs `index.handler` → `index.js|.mjs|.cjs`, python `app.handler` → `app.py`(점 표기 모듈 `pkg.app.handler` → `pkg/app.py`).

```bash
# nodejs: 디렉터리 내용을 루트에 담는다 (디렉터리 자체를 담지 말 것)
(cd build && zip -r -X ../api-handler.zip .)
# python: 의존성을 같은 루트에 설치
pip install -r requirements.txt -t package/ && cp app.py package/ && (cd package && zip -r -X ../api-handler.zip .)
```

Layer: 최상위는 `nodejs/`·`python/`·`bin/`·`lib/` 만 허용한다.

```bash
mkdir -p layer/nodejs && cp -r node_modules layer/nodejs/ && (cd layer && zip -r -X ../shared-utils.zip nodejs)
```

보내기 전에 로컬에서 handler 를 직접 돌려 테스트한다(ARONA 는 실행 테스트를 하지 않는다).

## 2. manifest 파일

zip 하나당 JSON 파일 하나. 필드는 `{zip, name, artifactKind, runtime, handler?, architectures?, compatibleRuntimes?, comment?}` 이고 모르는 필드는 거절된다. `zip` 은 manifest 파일 기준 상대경로. 나머지 필드는 `contracts/a2a/v1/lambda-artifact.schema.json` 제출 파트와 같다(`uploadId`·`sha256` 은 CLI 가 채운다).

함수:

```json
{
  "zip": "./api-handler.zip",
  "name": "api-handler",
  "artifactKind": "function",
  "runtime": "nodejs22.x",
  "handler": "index.handler",
  "architectures": ["arm64"]
}
```

Lambda@Edge:

```json
{
  "zip": "./spa-edge.zip",
  "name": "spa-edge",
  "artifactKind": "edge",
  "runtime": "nodejs22.x",
  "handler": "index.handler",
  "architectures": ["x86_64"]
}
```

Layer:

```json
{
  "zip": "./shared-utils.zip",
  "name": "shared-utils",
  "artifactKind": "layer",
  "runtime": "nodejs22.x",
  "compatibleRuntimes": ["nodejs22.x"],
  "architectures": ["x86_64", "arm64"]
}
```

규칙:
- `name`: `^[A-Za-z0-9_-]{1,64}$`. 요청 문장에서 이 이름으로 코드를 가리킨다. 같은 세션에 같은 이름으로 다시 내면 앞의 것을 대체한다.
- `function`·`edge` 는 `handler` 필수, `compatibleRuntimes` 금지, `architectures` 는 하나(생략 = `x86_64`). `edge` 는 `x86_64` 만.
- `layer` 는 `compatibleRuntimes`(1-2개) 필수, `handler` 금지, `runtime` 은 그중 빌드한 런타임. `architectures` 는 호환 아키텍처 목록(최대 2).

## 3. 요청과 함께 보내기

```bash
wikk agent send "api 함수를 nodejs22.x 로 만들고 코드는 제출한 아티팩트 api-handler 로 배포해 줘" \
  --cloud aws --account <account> --region <region> --team <team> \
  --lambda-artifact ./api-handler.json --json
```

새 요청 전에 `wikk catalog --cloud <cloud> --team <team> [--account <account> --region <region>]` 를 실행하거나 `wikk agent send` 가 출력하는 `=== Team catalog ===` 블록을 읽고, 이미 있는 리소스(함수·Layer·버킷 등)는 거기 적힌 정확한 이름으로 요청한다. 이름을 지어내지 않는다. `--task` 후속에는 필요 없다.

CLI 동작(`cli/internal/command/lambda_artifact.go`):
1. 모든 zip 의 sha256 을 계산하고 서버와 **같은 정적 검사**를 로컬에서 먼저 돌린다. 하나라도 실패하면 아무것도 올리지 않고 exit 1(`--json` 이면 `lambdaLocalChecks` 출력).
2. 한 메시지로 업로드 슬롯을 받고(1회용 presigned PUT, 세션·팀에 묶임, 15분 만료), 각 zip 을 슬롯 headers 그대로 PUT 한다(wikiwiki 토큰은 스토리지로 가지 않는다).
3. 요청 문장 + zip 마다 제출 파트를 같은 작업에 보낸다. 서버가 다시 해시·검사해 결과를 돌려준다.

- `--lambda-artifact` 는 zip 마다 반복, **메시지당 최대 8개**. 같은 `name` 을 두 번 주면 사용 오류(exit 2).
- 새 작업이면 scope 플래그(`--cloud --account --region --team`)가 필요하다. 이어서 보내려면 scope 대신 `--task <id>`.
- `send` 에서만 된다(`answer` 에서는 안 됨).
- `--lambda-artifact` 가 있으면 기본 타임아웃은 15분이다(업로드 + 첫 턴). 그래도 `context deadline exceeded` 로 끝나면 작업은 서버에서 계속 돈다: 같은 요청을 다시 보내지 말고 `wikk agent status <taskId> --wait` 로 기다린다.
- MCP 도구 `provision_agent_send` 로는 zip 을 올릴 수 없다. 항상 이 CLI 명령으로 보낸다.
- 세션당 미제출 슬롯은 최대 8개, 슬롯은 15분 뒤 만료된다. CLI 는 슬롯을 받자마자 올리고 제출하므로 보통 신경 쓸 필요 없다.

### 메모리·타임아웃 정하기

사용자가 함수의 메모리·타임아웃을 말하지 않았으면, 방금 빌드한 코드를 읽고 네가 정해 **요청 문장에 근거와 함께** 적는다. 코드에서 본 사실로 정하는 것이라 스펙 추측이 아니다. 근거 없이 값만 적지 않는다.

| 코드에서 본 것 | 메모리 | 타임아웃 |
| --- | --- | --- |
| 단순 API·이벤트 중계·SQS/SNS 전달 | 128–256 MB | 3–10초 |
| 외부 HTTP·DB 호출이 있는 처리 | 256–512 MB | 호출 타임아웃 합 × 2–3 |
| 이미지·PDF·압축 처리(Pillow, sharp, pdf 라이브러리) | 512–1024 MB | 30–60초 |
| ML 모델 로드, 큰 파일 일괄 처리 | 1024–2048 MB | 60–300초 |

- 메모리는 128·256·512·1024·2048 MB 중에서 고른다(서버가 받는 값). 타임아웃은 1–900초다.
- 메모리를 올리면 CPU 도 같이 늘어난다. 처리 시간이 긴 코드라면 메모리를 한 단계 올리는 편이 대개 싸고 빠르다.
- 판단이 어려우면 256 MB / 30초를 쓰고 그렇게 적는다. 운영 뒤 CloudWatch 사용량을 보고 바꾸면 된다.
- 문장 예: `"thumbnailer 함수를 python3.12 로 만들고 코드는 아티팩트 thumbnailer 로 배포해 줘. 메모리 1024MB, 타임아웃 60초(Pillow 로 최대 20MB 이미지를 리사이즈)."`
- 초안이 나오면(`INPUT_REQUIRED`) 이 값과 근거를 사용자에게 보여 준다. 사용자가 다른 값을 말하면 그 값이 이긴다.

## 4. 결과 읽기

업로드마다 stderr 에 `... Lambda 아티팩트 <name> 업로드 완료 (<n> bytes)` 가 찍힌다. 그 뒤 서버가 다시 해시·검사한다.

- 실패: 턴을 돌리지 않고 `INPUT_REQUIRED` 로 멈춘다. 텍스트 출력 `Lambda 아티팩트 <name>: 정적 검사 실패 (저장하지 않음)` + `[CODE] path: message`, `--json` 은 `lambdaResults`(`name, passed, sha256, unzippedBytes, issues[]`). 저장되지 않았다(exit 1). zip 을 고쳐 `--task <id>` 로 다시 보낸다(CLI 가 새 슬롯을 받는다).
- 통과: 결과 파트 없이 바로 요청 턴이 돈다(서버가 "정적 검사를 통과했습니다" 를 요청 문장에 붙인다). 출력은 평소 `send` 와 같다(초안·질문). 요청을 평소처럼 이어 간다(`wikk agent answer` / `wikk agent watch <id>`).

### 실패 issue 코드

zip 정적 검사(로컬·서버 공통, `apps/backend/pkg/lambdaartifact`):

| 코드 | 뜻 |
|---|---|
| `ZIP_TOO_LARGE` | zip 50MB 초과 |
| `EDGE_VIEWER_TOO_LARGE` | viewer 이벤트 Edge zip 1MB 초과 |
| `UNZIPPED_TOO_LARGE` | 압축 해제 총량 250MB 초과 |
| `TOO_MANY_ENTRIES` | 엔트리 10,000개 초과 |
| `COMPRESSION_RATIO` | 엔트리 압축률 100배 초과 |
| `PATH_TRAVERSAL` | `..`·절대경로·드라이브 문자·백슬래시 |
| `SYMLINK` | 심볼릭 링크 엔트리 |
| `DUPLICATE_ENTRY` | 같은 경로 엔트리 중복 |
| `HANDLER_MISSING` | handler 형식이 `<파일>.<함수>` 가 아니거나 파일이 zip 에 없음 |
| `RUNTIME_NOT_ALLOWED` | `nodejs22.x`·`python3.13` 외 런타임, Layer 의 `compatibleRuntimes` 누락 |
| `LAYER_LAYOUT` | Layer 최상위가 `nodejs/`·`python/`·`bin/`·`lib/` 외 |
| `EDGE_RUNTIME` | Edge 런타임이 허용 목록 밖이거나 `x86_64` 가 아님 |
| `INVALID_ZIP` | zip 으로 읽을 수 없음, 헤더 크기·CRC 불일치, 지원하지 않는 압축 방식 |

업로드 슬롯(서버만):

| 코드 | 뜻 |
|---|---|
| `UPLOAD_NOT_FOUND` | 그런 uploadId 의 슬롯이 없음 |
| `UPLOAD_SESSION_MISMATCH` | 다른 요청에 발급된 슬롯 |
| `UPLOAD_USED` | 이미 제출한 슬롯(한 번만 제출) |
| `UPLOAD_EXPIRED` | 15분 만료 |
| `UPLOAD_MISMATCH` | artifactKind·sha256 이 슬롯 받을 때와 다름 |
| `UPLOAD_MISSING` | 올린 zip 이 없음(headers 를 그대로 보내 PUT 했는지 확인) |
| `SHA256_MISMATCH` | 올린 객체의 크기·sha256 이 슬롯 값과 다름 |

범위 거절(`scope_account_unknown`·`team_unknown`·`scope_region_*`, 또는 `reasonCode: kind_outside_session_scope` 항목)이면 `refusal.validValues`·`required` 플래그 중 사용자 요청이 가리키는 값으로 고쳐 다시 보낸다(비슷해 보이는 값을 대신 고르지 않는다).

## 5. Lambda@Edge 제약

zip 검사를 통과해도 요청 단계에서 아래를 어기면 막힌다(`SVL.EDGE_*`, `INTENT.LAMBDA_ARTIFACT_TOO_LARGE`):

- 리전 **us-east-1** 만, 아키텍처 **x86_64** 만.
- 환경 변수·VPC·Layer·예약 동시성 금지.
- viewer-request·viewer-response: zip **1MB**, 메모리 **128MB**, 타임아웃 **5초** 이하.
- origin-request·origin-response: 타임아웃 **30초** 이하(zip 50MB).
- 실행 역할에 Lambda@Edge 신뢰가 필요하다. 초안의 역할이면 ARONA 가 "신뢰 추가" 질문으로 확인하고, 답한 경우에만 역할에 적는다(몰래 채우지 않음). 초안 밖 기존 역할은 질문 없이 `SVL.EDGE_TRUST_REQUIRED` 로 막힌다. Edge 신뢰가 붙은 역할은 일반 함수와 같이 쓰지 말고 따로 둔다.
- 새 Edge 함수를 cdn 에 바로 연결하는 건 cdn 이 같은 us-east-1 target 일 때만 된다. 아니면 Edge 함수를 먼저 만들고 다음 요청에서 기존 함수로 연결한다.
- 기존 함수를 Edge 로 바꾸거나 이벤트를 바꾸려면 새 `edge` zip 이 필요하다.

## 6. Layer 규칙

- 함수에 붙이는 Layer 는 같은 요청의 새 Layer 또는 **같은 워크로드**의 ARONA 관리 Layer 만(다른 워크로드의 Layer 는 쓸 수 없다). 서드파티·다른 계정 Layer ARN 은 안 된다.
- 함수당 최대 **5개**. 런타임·아키텍처가 Layer 호환 목록에 있어야 한다(`SVL.LAYER_RUNTIME_INCOMPATIBLE`·`SVL.LAYER_ARCHITECTURE_INCOMPATIBLE`).
- Layer 는 생성·코드 교체(새 버전 게시)만 된다. **삭제는 없다**: 이전 버전은 보존(`Retain`)되고 자동 삭제되지 않는다.

## 7. 코드 교체

ARONA 관리 함수·Layer 의 코드를 바꾸려면 새 zip 을 제출하고 요청 문장에 그 이름을 적는다. 코드 없이 다른 설정만 바꾸는 수정은 배포된 zip(과 handler·architecture)을 그대로 둔다. 요청 단계 오류: `INTENT.LAMBDA_ARTIFACT_NOT_FOUND`(이 세션에 제출되지 않은 이름), `INTENT.LAMBDA_ARTIFACT_MISMATCH`(종류·런타임이 다른 zip).

## 8. Flink 애플리케이션 jar

`flink_application` 의 코드는 manifest 없이 jar 파일 하나로 보낸다.

```bash
wikk agent send "click-job Flink 앱을 이 jar 로 만들어 줘" \
  --flink-artifact ./target/click-job.jar \
  --cloud aws --account <키> --region <리전> --team <팀>
```

- 파일 이름(확장자 제외)이 `applicationCode.artifactId` 다: `click-job.jar` → `click-job`. 1-64자의 영문·숫자·`-`·`_` 만 쓴다.
- 확장자는 `.jar` 또는 `.zip`. zip 형식(`PK` 로 시작)과 크기 상한(기본 512MiB, 서버 설정 `PROVISION_AGENT_FLINK_ARTIFACT_MAX_BYTES`)만 검사하고 jar 내용(클래스·의존성)은 보지 않는다. 런타임·handler 는 없다.
- 로컬 검사 실패는 exit 1(아무것도 올리지 않음), 업로드·제출·새 작업의 scope 규칙은 `--lambda-artifact` 와 같다. `--lambda-artifact` 와 함께 쓸 수 있다.
- 적용 때 ARONA 가 jar 를 계정 코드 버킷의 `code/<sha256>.jar` 로 복사해 객체 버전을 고정한다(요청에 버전을 적지 않는다).

## 8. Flink 애플리케이션 jar

`flink_application` 의 코드는 manifest 없이 jar 파일 하나로 보낸다.

```bash
wikk agent send "click-job Flink 앱을 이 jar 로 만들어 줘" \
  --flink-artifact ./target/click-job.jar \
  --cloud aws --account <키> --region <리전> --team <팀>
```

- 파일 이름(확장자 제외)이 `applicationCode.artifactId` 다: `click-job.jar` → `click-job`. 1-64자의 영문·숫자·`-`·`_` 만 쓴다.
- 확장자는 `.jar` 또는 `.zip`. zip 형식(`PK` 로 시작)과 크기 상한(기본 512MiB, 서버 설정 `PROVISION_AGENT_FLINK_ARTIFACT_MAX_BYTES`)만 검사하고 jar 내용(클래스·의존성)은 보지 않는다. 런타임·handler 는 없다.
- 로컬 검사 실패는 exit 1(아무것도 올리지 않음), 업로드·제출·새 작업의 scope 규칙은 `--lambda-artifact` 와 같다. `--lambda-artifact` 와 함께 쓸 수 있다.
- 적용 때 ARONA 가 jar 를 계정 코드 버킷의 `code/<sha256>.jar` 로 복사해 객체 버전을 고정한다(요청에 버전을 적지 않는다).

## Install

`wikk` 이 실행될 때 `wikiwiki-provision` 스킬과 함께 `~/.claude/skills/lambda-artifact/`(Claude Code), `~/.agents/skills/lambda-artifact/`(Codex·pi·OpenCode)에 자동으로 설치한다. 원본은 `cli/internal/agentskill/lambda-artifact/SKILL.md` 이고 저장소의 `skills/lambda-artifact/SKILL.md` 는 그 심볼릭 링크다.
