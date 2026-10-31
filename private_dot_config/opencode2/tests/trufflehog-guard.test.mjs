import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import guard from '../plugins/trufflehog-guard.js';

test('guard works with an untrusted-project Python shim and still blocks sensitive reads', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'opencode2-guard-'));
  const oldPath = process.env.PATH;
  try {
    // Simulate mise refusing to launch Python in an untrusted worktree.
    fs.writeFileSync(path.join(directory, 'python3'), '#!/bin/sh\nexit 1\n', { mode: 0o700 });
    fs.writeFileSync(path.join(directory, 'AGENTS.md'), '# Project instructions\n');
    process.env.PATH = `${directory}:${oldPath || ''}`;
    let read;
    let shell;
    await guard.setup({
      location: { directory },
      tool: { hook: async (_, callback) => { read = callback; } },
      shell: { hook: async (_, callback) => { shell = callback; } },
    });
    await read({ tool: 'read', input: { path: 'AGENTS.md' } });
    await shell({ command: 'cat AGENTS.md', cwd: directory });
    const sensitive = path.join(os.homedir(), '.aws', 'credentials');
    await assert.rejects(read({ tool: 'read', input: { path: sensitive } }), /well-known sensitive file/);
    await assert.rejects(shell({ command: `cat '${sensitive}'`, cwd: directory }), /well-known sensitive file/);
  } finally {
    if (oldPath === undefined) delete process.env.PATH;
    else process.env.PATH = oldPath;
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
