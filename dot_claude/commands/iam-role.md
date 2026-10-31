---
description: Generate a least-privilege IAM role staging package for DevOps review
argument-hint: <service or source description>
---

If the request is exactly `cancel`, acknowledge cancellation and stop without tools. Otherwise handle this /iam-role request in the parent conversation. Before any analysis, shell command, or delegation, call `AskUserQuestion` with one single-choice question: "요청하시는 역할은 service role(서비스/워크로드용)인가요, user role(사람이 사용하는 접근 권한용)인가요?" Options: `service role`, `user role`. Do not infer the type, even when the request names it. Wait for the real tool response.

Read-only tools and AWS read commands are exempt from the confirmation timing above. After the role answer, call `AskUserQuestion` again for the execution AWS account/profile. The hook lists all discovered profiles with STS status, including failed profiles. A failed selection requires login guidance and termination, never automatic login/retry or another account question. Next-page navigation is allowed; never guess the account. Paginated account pages omit the cancel row (four-option tool limit); if the user cancels through the free-text "Other" input, guide them to `/iam-role cancel`.

If source analysis cannot identify a target resource's owning account, ask "이 리소스(<reference>)는 어느 AWS 계정에 있나요?" with exactly `header: "리소스 계정"`, one resource at a time. The hook supplies the account choices. Handle such requests returned by the child in this parent conversation, then resume the child with the answers. Record ownership separately from the execution account; do not ask region/location or overwrite the execution profile. Explicit source ownership requires no extra question.

For either `service role` or `user role`, delegate to `iam-role-creator` with the request, both question call IDs, role, selected profile and STS Account ID. Tell the child both parent questions are complete for this request; do not repeat discovery or questions. A user role must use an explicitly confirmed IAM user/role principal ARN, never a default service principal or an IAM User creation path. Handle any missing principal confirmation in this parent conversation and resume the child. On dismissal, do not continue; offer `/iam-role cancel`.

Request:

$ARGUMENTS
