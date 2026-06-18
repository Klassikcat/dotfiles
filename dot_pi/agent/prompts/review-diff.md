Use the OMO-inspired reviewer lane.

Review task: {{task}}

Use `subagent` with `agentScope: "both"` to ask `momus` to review recent changes.

Reviewer instructions:
- Start with git status and git diff.
- Inspect changed files and relevant neighboring code.
- Report severity, confidence, evidence, and concrete fixes.
- Do not edit files.

Then summarize the review verdict and recommended next actions.
