---
name: cloudfront-function
description: Write a new CloudFront Function (code + tests) locally and send it to ARONA (wikiwiki provision agent) over A2A with `wikk agent send --cloudfront-function`. Use when a resource request needs a CloudFront Function that does not exist yet (SPA rewrite, redirect, header rewrite). Not for attaching an existing LIVE function: name it in the request text instead.
---

# CloudFront Function via A2A

ARONA never writes or edits function code. You (the local coding agent) write the code and its tests; ARONA runs the tests remotely, stores the function only when they pass, shows the full code and its sha256 to a human approver, and the executor publishes exactly that code. Every new function needs human approval.

## 1. Write the function file

One JSON file per function (`contracts/a2a/v1/cloudfront-function.schema.json`):

```json
{
  "name": "acme-dev-web-spa-rewrite",
  "eventType": "viewer-request",
  "runtime": "cloudfront-js-2.0",
  "code": "function handler(event) {\n  var request = event.request;\n  if (!request.uri.includes('.')) request.uri = '/index.html';\n  return request;\n}",
  "tests": [
    { "name": "route goes to index", "request": { "method": "GET", "uri": "/about" }, "expect": { "uri": "/index.html" } },
    { "name": "asset untouched", "request": { "method": "GET", "uri": "/app.js" }, "expect": { "uri": "/app.js" } }
  ]
}
```

Rules:
- `name`: `^[A-Za-z0-9_-]{1,64}$`; follow the team's resource naming rule (`{org}-{env}-{name}-{type}`). It must not already exist in the account.
- `code`: at most 10240 UTF-8 bytes, declares `function handler(event)`, cloudfront-js-2.0 only. The remote test runs it in an isolated JS engine with no modules, network or Node globals, so code using `require` (including `crypto`) fails there.
- The approver must see the full source: if `{eventType, codeSha256, code}` as JSON exceeds 16 KiB (escaped characters such as `\` and `"` count twice), it is refused as `REVIEW_TOO_LARGE`. Keep code short and avoid large escape-heavy literals.
- `tests`: 1-20. `request.uri` starts with `/`; headers, querystring and cookies are `{name: value}` maps. `viewer-response` tests need `response: {statusCode, headers}`; `viewer-request` tests must not have it. `expect` checks `uri`, `statusCode` and/or `headers` (header names compared lowercase).
- Cover the main path and at least one case the function must leave unchanged.

Check locally before sending: run the handler under Node with the same event shape (`{version:'1.0', context:{eventType}, viewer:{ip}, request:{method, uri, querystring:{k:{value}}, headers:{k:{value}}, cookies:{k:{value}}}}`).

## 2. Send it with the request

The request text must attach the function by name to a cdn behavior:

```bash
wikk agent send "web cdn 기본 동작에 viewer-request 함수 acme-dev-web-spa-rewrite 를 연결해 줘" \
  --cloud aws --account <account> --region <region> --team <team> \
  --cloudfront-function ./acme-dev-web-spa-rewrite.json --json
```

- Before a new request, run `wikk catalog --cloud <cloud> --team <team> [--account <account> --region <region>]` (or read the `=== Team catalog ===` block `wikk agent send` prints) and use the exact names of resources that already exist (the cdn, other functions); do not invent names. Follow-ups with `--task` skip it.
- Repeat `--cloudfront-function` per function (at most 4 per message). Add `--task <id>` to continue an existing task instead of the scope flags.
- Function files are only accepted on `send`, not with `answer`.

## 3. Read the remote test result

`--json` output has `functionTests`: one report per function with `passed`, `codeSha256`, `staticIssues`, `error` and per-test `results` (`mismatches`, `error`). Text output prints `CloudFront Function <name>: 테스트 통과 (저장됨)` or `테스트 실패 (저장하지 않음)`.

- Failed: nothing was stored and the task waits for input. Fix the code or the tests and send the file again with `--task <id>`.
- Passed: the function is stored for this session; continue the request normally (`wikk agent watch <id>`).

If a send is refused for scope (`scope_account_unknown`, `team_unknown`, `scope_region_*`, or an item with `reasonCode: kind_outside_session_scope`), use the listed `refusal.validValues` / `required` flag that the user's request names, then resend; never pick a similar-looking value yourself.

## 4. Approval and apply

The approver sees the full code, event type and sha256 in the plan diff. On apply the executor creates the function in DEVELOPMENT with ownership tags, reruns the same tests on CloudFront (`TestFunction`), publishes to LIVE only if the code hash still matches the approved one, then associates it. Any failure before publishing deletes the created function. An existing function with the same name and different code is never overwritten.

## Install

`wikk` installs this skill next to `wikiwiki-provision` on every run: `~/.claude/skills/cloudfront-function/` (Claude Code) and `~/.agents/skills/cloudfront-function/` (Codex, pi, OpenCode). The source is `cli/internal/agentskill/cloudfront-function/SKILL.md`; the repo's `skills/cloudfront-function/SKILL.md` is a symlink to it.
