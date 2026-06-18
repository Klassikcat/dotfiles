Task: {{task}}

Use `subagent` with `agentScope: "both"` in a chain:
1. `explore`: gather relevant repository context.
2. `metis`: create an implementation plan using the exploration output: {previous}

Do not implement. Return the plan, affected files, validation commands, and risks.
