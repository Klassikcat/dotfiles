# Global instructions (OpenCode V2 profile)

## Delegation: fan out codebase search to subagents

These instructions explicitly ask for subagent delegation and parallel agent work.
They override any default guidance that says not to spawn subagents.

- For any codebase exploration, discovery, or context-gathering step, use the `subagent` tool
  with the `explore` agent instead of running `grep`, `glob`, `read`, or `shell` searches yourself.
  Examples: "where is X implemented", "how does Y flow", "which files touch Z", "what conventions
  does this repo use", locating configs, tracing call paths.
- Fan out: when there are 2+ independent questions or search areas, launch multiple `explore`
  subagents in a single message (parallel tool calls), one focused question per subagent.
  Give each one a complete, self-contained prompt and state exactly what it should return
  (absolute paths, line numbers, key findings, gaps).
- Use `librarian` for external documentation, library APIs, and upstream source lookups.
- Use `multimodal-looker` for images, screenshots, diagrams, and PDFs.
- Do not duplicate work you delegated; continue with non-overlapping work or wait for results.
- Exceptions where direct tools are fine: you already know the exact file path, you are reading
  1-3 specific files, or the search is a single exact symbol/string you can `grep` in one call.
- The `plan` agent must also delegate exploration this way; only the final plan is written directly.
