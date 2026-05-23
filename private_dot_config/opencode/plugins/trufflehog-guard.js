// Trufflehog-based credential file guard for opencode.
// Delegates per-file scanning + matching to ~/.claude/hooks/trufflehog-guard.py
// so reads are checked immediately before the target file is opened.

import { spawn } from "node:child_process";
import { homedir } from "node:os";
import path from "node:path";
import { existsSync } from "node:fs";

const HOME = homedir();
const SCRIPT = path.join(HOME, ".claude", "hooks", "trufflehog-guard.py");

function runHook(mode, payload, timeoutMs) {
  return new Promise((resolve) => {
    if (!existsSync(SCRIPT)) {
      resolve(null);
      return;
    }
    const proc = spawn("python3", [SCRIPT, mode], {
      stdio: ["pipe", "pipe", "pipe"],
    });
    let stdout = "";
    let killed = false;
    const timer = setTimeout(() => {
      killed = true;
      try { proc.kill("SIGKILL"); } catch {}
    }, timeoutMs);
    proc.stdout.on("data", (d) => { stdout += d.toString(); });
    proc.on("error", () => { clearTimeout(timer); resolve(null); });
    proc.on("close", () => {
      clearTimeout(timer);
      if (killed) { resolve(null); return; }
      try { resolve(JSON.parse(stdout.trim() || "{}")); }
      catch { resolve(null); }
    });
    try {
      proc.stdin.write(JSON.stringify(payload));
      proc.stdin.end();
    } catch {
      resolve(null);
    }
  });
}

export const TrufflehogGuard = async ({ directory }) => {
  const cwd = directory || process.cwd();

  return {
    "tool.execute.before": async (input, output) => {
      const tool = (input && input.tool) || "";
      if (tool.toLowerCase() !== "read") return;

      const args = (output && output.args) || {};
      const filePath = args.filePath || args.file_path || args.path;
      if (!filePath) return;

      const result = await runHook(
        "check",
        {
          tool_name: "Read",
          tool_input: { file_path: filePath },
          cwd,
        },
        20_000,
      );

      const decision = result?.hookSpecificOutput?.permissionDecision;
      if (decision === "deny") {
        const reason =
          result.hookSpecificOutput.permissionDecisionReason ||
          `Read of '${filePath}' blocked by trufflehog-guard.`;
        throw new Error(reason);
      }
    },
  };
};
