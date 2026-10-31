// ARONA for pi: widget above the editor with my in-flight requests, notify on status changes.
// wikk installs this next to arona.ts, the Claude Code mod's shared logic (agentskill/arona/hooks/arona.ts).
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { action, dots, isShown, label, statusKey, toReqs, transition } from "./arona";

type Req = NonNullable<ReturnType<typeof toReqs>>[number];

export default function (pi: ExtensionAPI) {
  let timer: ReturnType<typeof setInterval> | undefined;
  let busy = false;
  let hidden = false;
  let error = "";
  let seen: Record<string, string> | null = null;
  let shown: Req[] = [];
  const changed: Record<string, number> = {};
  // Bumped on session start and shutdown: a poll that outlives its session must not touch the
  // replaced ctx, whose ui and pi.exec throw once pi invalidates the old runtime.
  let generation = 0;

  // wikk is the CLI's name; installs older than the rename only have wikiwiki.
  async function list(): Promise<{ reqs: Req[] } | { error: string }> {
    let last = "wikk not installed";
    for (const cli of ["wikk", "wikiwiki"]) {
      const ran = await pi.exec(cli, ["resource", "list", "--limit", "20", "--json"], { timeout: 20_000 }).catch(() => null);
      // pi.exec resolves a spawn failure (missing binary) as code 1 with no output.
      if (!ran || (ran.code !== 0 && !ran.stdout && !ran.stderr)) continue;
      if (ran.killed) return { error: `${cli} timed out` };
      const parsed = ran.code === 0 ? toReqs(ran.stdout) : null;
      if (parsed) return { reqs: parsed };
      last = (ran.stderr || ran.stdout).trim().slice(0, 200) || `${cli} exited ${ran.code}`;
    }
    return { error: last };
  }

  function draw(ctx: ExtensionContext, reqs: Req[]) {
    shown = reqs;
    const now = Date.now();
    const rows = error
      ? [`◉ ARONA 조회 실패: ${error} (로그인: wikk auth login)`]
      : reqs.slice(0, 5).map((r) => `◉ ARONA ${r.id.slice(0, 8)} ${dots(r.status)} ${label(r, now)}${r.failure ? ` · ${r.failure}` : ""}${action(r) ? ` → ${action(r)}` : ""}`);
    if (!error && reqs.length > 5) rows.push(`◉ ARONA 외 ${reqs.length - 5}건 — /arona`);
    ctx.ui.setWidget("arona", hidden || rows.length === 0 ? undefined : rows);
  }

  async function refresh(ctx: ExtensionContext) {
    if (busy) return null;
    busy = true;
    const mine = generation;
    try {
      const got = await list();
      if (mine !== generation) return null;
      if ("error" in got) {
        if (!error) ctx.ui.notify(`ARONA 조회 실패: ${got.error}`, "warning");
        error = got.error;
        draw(ctx, []);
        return got;
      }
      if (error) ctx.ui.notify("ARONA 조회 복구됨", "info");
      error = "";
      const now = Date.now();
      const next: Record<string, string> = {};
      for (const r of got.reqs) {
        next[r.id] = statusKey(r);
        // The first poll is a silent baseline, else every old request would notify as new.
        const news = seen && transition(seen[r.id], r, now);
        if (news) {
          ctx.ui.notify(news, r.failure ? "error" : "info");
          changed[r.id] = now;
        }
      }
      seen = next;
      draw(ctx, got.reqs.filter((r) => isShown(r, now, changed[r.id])));
      return got;
    } finally {
      busy = false;
    }
  }

  const poll = (ctx: ExtensionContext) => void refresh(ctx).catch(() => {});

  pi.on("session_start", (_event, ctx) => {
    generation++;
    clearInterval(timer);
    if (!ctx.hasUI) return;
    timer = setInterval(() => poll(ctx), 30_000);
    poll(ctx);
  });

  pi.on("session_shutdown", () => {
    generation++;
    clearInterval(timer);
    timer = undefined;
  });

  pi.registerCommand("arona", {
    description: "ARONA requests. Args: hide | show | (none: list my recent requests)",
    handler: async (args, ctx) => {
      const arg = args.trim();
      if (arg === "hide" || arg === "show") {
        hidden = arg === "hide";
        draw(ctx, shown);
        ctx.ui.notify(`ARONA widget ${hidden ? "hidden" : "shown"}.`, "info");
        return;
      }
      const got = (await refresh(ctx)) ?? (await list());
      if ("error" in got) return ctx.ui.notify(`ARONA: ${got.error}`, "error");
      const now = Date.now();
      ctx.ui.notify(
        got.reqs.length
          ? got.reqs.slice(0, 10).map((r) => `${r.id.slice(0, 8)}  ${dots(r.status)} ${label(r, now)}${r.failure ? ` · ${r.failure}` : ""}${action(r) ? ` → ${action(r)}` : ""}`).join("\n")
          : "ARONA 요청이 없습니다.",
        "info",
      );
    },
  });
}
