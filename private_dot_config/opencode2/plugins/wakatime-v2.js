import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';

// Track native V2 tool inputs, not V1 message.part.updated metadata.
function changes(event) {
  if (event.status !== 'completed') return [];
  const input = event.input ?? {};
  const tool = event.tool;
  // V2 edit/patch return authoritative FileDiff.Info records in result.output.
  const diffs = event.result?.output?.files;
  if (['edit', 'patch', 'apply_patch', 'multiedit'].includes(tool) && Array.isArray(diffs) && diffs.length) {
    return diffs.filter((diff) => typeof diff.file === 'string').map((diff) => ({
      file: diff.file, isWrite: true,
      lineChanges: (diff.additions ?? 0) - (diff.deletions ?? 0),
    }));
  }
  if (['read', 'write', 'edit', 'multiedit'].includes(tool)) {
    const file = input.path ?? input.filePath ?? input.filepath;
    return typeof file === 'string' && file ? [{ file, isWrite: tool !== 'read' }] : [];
  }
  if (tool !== 'patch' && tool !== 'apply_patch') return [];
  const patch = input.patch ?? input.patchText ?? input.patch_text ?? input.text;
  if (typeof patch !== 'string') return [];
  const files = [];
  let current;
  for (const line of patch.split(/\r?\n/)) {
    const header = line.match(/^\*\*\* (?:Add|Update|Delete) File: (.+)$/);
    if (header) {
      current = { file: header[1], isWrite: true, lineChanges: 0 };
      files.push(current);
    } else if (current && line.startsWith('*** Move to: ')) {
      current.file = line.slice('*** Move to: '.length);
    } else if (current && line.startsWith('+')) {
      current.lineChanges++;
    } else if (current && line.startsWith('-')) {
      current.lineChanges--;
    }
  }
  return files;
}

export default {
  id: 'wakatime-v2',
  async setup(ctx) {
    const home = (process.env.WAKATIME_HOME || os.homedir()).replace(/^~(?=\/|$)/, os.homedir());
    const resources = process.env.WAKATIME_HOME ? home : path.join(home, '.wakatime');
    const installed = path.join(resources, 'wakatime-cli');
    const cli = ctx.options?.cli ?? process.env.WAKATIME_CLI_PATH ?? (fs.existsSync(installed) ? installed : 'wakatime-cli');
    const project = ctx.location.project?.directory ?? ctx.location.directory;
    const directory = ctx.location.directory;
    const plugin = `opencode2-${ctx.app.name}/${ctx.app.version} opencode2-wakatime/1.0.0`;
    const pending = new Map();
    const seen = new Set();
    const interval = 60_000;
    let lastSent = 0;
    let timer;
    let running = Promise.resolve();
    let disposed = false;
    const warn = (message) => {
      // Never log API keys, command arguments, file contents or CLI stderr.
      try {
        fs.mkdirSync(resources, { recursive: true });
        fs.appendFileSync(path.join(resources, 'opencode2.log'), `${new Date().toISOString()} ${message}\n`, { mode: 0o600 });
      } catch { /* Tracking must not break coding. */ }
    };
    const send = (batch) => new Promise((resolve) => {
      const first = batch[0];
      const args = ['--entity', first.entity, '--entity-type', 'file', '--time', String(first.time),
        '--category', 'ai coding', '--plugin', plugin, '--project-folder', project,
        '--config', path.join(home, '.wakatime.cfg'), '--timeout', '10', '--extra-heartbeats'];
      if (first.is_write) args.push('--write');
      if (first.ai_line_changes) args.push('--ai-line-changes', String(first.ai_line_changes));
      // The installed CLI handles exclusions, privacy settings, auth, and offline retries.
      const child = spawn(cli, args, { stdio: ['pipe', 'ignore', 'ignore'], windowsHide: true });
      const timeout = setTimeout(() => child.kill('SIGKILL'), 15_000);
      timeout.unref();
      child.stdin.on('error', () => {});
      child.on('error', (error) => {
        clearTimeout(timeout);
        warn(`WakaTime CLI unavailable (${error.code ?? 'spawn error'})`);
        resolve();
      });
      child.on('close', (code, signal) => {
        clearTimeout(timeout);
        if (code || signal) warn(`WakaTime CLI exited ${code ?? signal}; check wakatime.log`);
        resolve();
      });
      child.stdin.end(JSON.stringify(batch.slice(1)));
    });
    const flush = () => {
      clearTimeout(timer);
      timer = undefined;
      if (!pending.size) return running;
      const batch = [...pending.values()];
      pending.clear();
      lastSent = Date.now();
      running = running.then(() => send(batch)).catch(() => warn('Heartbeat batch failed'));
      return running;
    };
    await ctx.tool.hook('execute.after', (event) => {
      if (disposed) return;
      const files = changes(event);
      if (!files.length) return;
      const key = event.id ? `${event.sessionID}:${event.id}` : undefined;
      if (key && seen.has(key)) return;
      if (key) seen.add(key);
      if (seen.size > 2000) seen.delete(seen.values().next().value);
      for (const change of files) {
        const entity = path.resolve(directory, change.file.replace(/^~\//, `${os.homedir()}/`));
        try { if (fs.statSync(entity).isDirectory()) continue; } catch { /* Deleted files may still be reported. */ }
        const previous = pending.get(entity);
        pending.set(entity, {
          entity, type: 'file', time: Date.now() / 1000, category: 'ai coding', plugin,
          project_folder: project, is_write: change.isWrite || previous?.is_write || false,
          ai_line_changes: (previous?.ai_line_changes ?? 0) + (change.lineChanges ?? 0),
        });
      }
      if (pending.size && !timer) {
        timer = setTimeout(() => { void flush(); }, Math.max(1000, interval - (Date.now() - lastSent)));
        timer.unref();
      }
    });
    const controller = new AbortController();
    const events = (async () => {
      for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
        const data = event.data ?? event.properties;
        if (event.type === 'session.idle' || event.type === 'session.deleted' ||
            (event.type === 'session.status' && data?.status?.type === 'idle')) void flush();
      }
    })().catch(() => { if (!disposed) warn('WakaTime event subscription stopped'); });
    return async () => {
      disposed = true;
      controller.abort();
      await flush();
      await events;
    };
  },
};
