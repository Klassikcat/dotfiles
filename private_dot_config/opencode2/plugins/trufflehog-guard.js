import { spawn } from "node:child_process";
import { homedir } from "node:os";
import path from "node:path";

const script = "/home/shinjungtae/Projects/Personal/opencode-hooks/hooks-opencode/trufflehog-guard/trufflehog-guard.py";

async function check(payload) {
  const output = await new Promise((resolve, reject) => {
    // A project-local mise shim can refuse to run in a new, untrusted worktree.
    const proc = spawn("/usr/bin/python3", [script, "check"], {
      cwd: payload.cwd,
      stdio: ["pipe", "pipe", "ignore"],
      env: { ...process.env, PATH: `${path.join(homedir(), ".local/bin")}:${process.env.PATH || ""}` },
    });
    let stdout = "";
    proc.stdout.on("data", (chunk) => { stdout += chunk.toString(); });
    proc.on("error", reject);
    proc.stdin.on("error", reject);
    proc.on("close", (code) => {
      if (code !== 0) reject(new Error("trufflehog-guard: scanner failed"));
      else resolve(stdout);
    });
    proc.stdin.end(JSON.stringify(payload));
  });
  const result = JSON.parse(output || "{}");
  const decision = result.hookSpecificOutput;
  if (decision?.permissionDecision === "deny") {
    throw new Error(decision.permissionDecisionReason || "Blocked by trufflehog-guard");
  }
}

export default {
  id: "trufflehog-guard",
  async setup(ctx) {
    await ctx.tool.hook("execute.before", async (event) => {
      if (event.tool !== "read") return;
      const input = event.input;
      const filePath = input?.path || input?.filePath || input?.file_path;
      if (!filePath) return;
      await check({ tool_name: "Read", tool_input: { file_path: filePath }, cwd: ctx.location.directory });
    });
    await ctx.shell.hook("create.before", async (event) => {
      await check({ tool_name: "Bash", tool_input: { command: event.command }, cwd: event.cwd });
    });
  },
};
