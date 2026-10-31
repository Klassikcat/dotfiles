import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import ponytail from '../plugins/ponytail-v2.js';
import wakatime from '../plugins/wakatime-v2.js';

const temporary = () => fs.mkdtempSync(path.join(os.tmpdir(), 'opencode2-integrations-'));

test('Ponytail native commands, skills, independent state and per-turn system context', async () => {
  const directory = temporary();
  try {
    const statePath = path.join(directory, '.ponytail-active');
    const commands = new Map();
    const skills = [];
    const notices = [];
    const prompts = [];
    let transform;
    await ponytail.setup({
      options: { statePath },
      session: {
        hook: async (name, callback) => { assert.equal(name, 'context'); transform = callback; },
        synthetic: async (notice) => notices.push(notice),
        prompt: async (prompt) => prompts.push(prompt),
      },
      command: { transform: async (edit) => edit({ add: (item) => commands.set(item.name, item) }) },
      skill: { transform: async (edit) => edit({ add: (item) => {
        // OpenCode 2.0.16 Skill.Info rejects legacy location/slash fields.
        for (const key of ['id', 'name', 'path', 'content']) assert.equal(typeof item[key], 'string', `Skill.Info.${key}`);
        const allowed = new Set(['id', 'name', 'description', 'autoinvoke', 'path', 'content']);
        for (const key of Object.keys(item)) assert.ok(allowed.has(key), `Unsupported Skill.Info field: ${key}`);
        skills.push(item);
      } }) },
    });
    assert.equal(commands.size, 6);
    assert.equal(skills.length, 6);
    assert.ok(skills.every((skill) => fs.existsSync(skill.path) && skill.content.length > 0));
    for (const mode of ['lite', 'full', 'ultra', 'review', 'off']) {
      await commands.get('ponytail').execute({ sessionID: 'test', prompt: { text: mode } });
      assert.equal(fs.readFileSync(statePath, 'utf8'), mode);
      const event = { system: [{ type: 'text', text: 'original' }] };
      transform(event);
      assert.equal(event.system[0].text, 'original');
      assert.equal(event.system.length, mode === 'off' ? 1 : 2);
      if (mode !== 'off') assert.match(event.system[1].text, new RegExp(`level: ${mode}`));
    }
    await commands.get('ponytail').execute({ sessionID: 'test', prompt: { text: 'status' } });
    assert.equal(notices.at(-1).text, 'Ponytail: off');
    assert.ok(notices.every((notice) => notice.resume === false));
    await assert.rejects(commands.get('ponytail').execute({ prompt: { text: 'invalid' } }), /Usage/);
    assert.equal(fs.readFileSync(statePath, 'utf8'), 'off');
    await commands.get('ponytail-review').execute({ sessionID: 'test', prompt: { text: '$& literal argument', files: [] }, delivery: 'steer' });
    assert.equal(prompts[0].sessionID, 'test');
    assert.equal(prompts[0].delivery, 'steer');
    assert.ok(prompts[0].text.includes('$& literal argument'));
    assert.equal(fs.readFileSync(statePath, 'utf8'), 'off');
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});

async function tracker(directory, cli) {
  let callback;
  const dispose = await wakatime.setup({
    options: { cli },
    app: { name: 'cli', version: '0.0.0-beta-19289' },
    location: { directory, project: { directory } },
    tool: { hook: async (name, handler) => { assert.equal(name, 'execute.after'); callback = handler; } },
    event: { subscribe: ({ signal }) => (async function* () {
      await new Promise((resolve) => {
        if (signal.aborted) resolve();
        else signal.addEventListener('abort', resolve, { once: true });
      });
    })() },
  });
  return { callback, dispose };
}

test('WakaTime batches V2 read/write/edit/patch, deduplicates and flushes without secrets', async () => {
  const directory = temporary();
  const oldHome = process.env.WAKATIME_HOME;
  process.env.WAKATIME_HOME = directory;
  try {
    const capture = path.join(directory, 'capture.jsonl');
    const cli = path.join(directory, 'fake-cli');
    fs.writeFileSync(cli, `#!${process.execPath}\nlet data='';process.stdin.on('data',d=>data+=d);process.stdin.on('end',()=>require('fs').appendFileSync(${JSON.stringify(capture)},JSON.stringify({args:process.argv.slice(2),extra:JSON.parse(data)})+'\\n'));\n`, { mode: 0o700 });
    const { callback, dispose } = await tracker(directory, cli);
    const tool = (id, name, input, result) => callback({ sessionID: 'a', id, tool: name, input, result, status: 'completed' });
    await tool('read', 'read', { path: 'one.ts' });
    await tool('edit', 'edit', { path: 'one.ts' }, { output: { files: [{ file: 'one.ts', additions: 5, deletions: 2 }] } });
    await tool('edit', 'edit', { path: 'one.ts' }, { output: { files: [{ file: 'one.ts', additions: 5, deletions: 2 }] } });
    await tool('write', 'write', { path: 'two.ts', content: 'SECRET MUST NOT BE SENT' });
    await tool('patch', 'patch', { patchText: '*** Begin Patch\n*** Update File: old.ts\n*** Move to: renamed.ts\n-old\n+new\n+extra\n*** End Patch' });
    await tool('directory', 'read', { path: directory });
    await tool('shell', 'bash', { command: 'echo ignored' });
    await callback({ id: 'failed', status: 'error', tool: 'write', input: { path: 'failed.ts' } });
    await dispose();
    const batches = fs.readFileSync(capture, 'utf8').trim().split('\n').map((line) => JSON.parse(line));
    assert.equal(batches.length, 1);
    const { args, extra } = batches[0];
    assert.equal(args[args.indexOf('--entity') + 1], path.join(directory, 'one.ts'));
    assert.ok(args.includes('--write'));
    assert.equal(args[args.indexOf('--ai-line-changes') + 1], '3');
    assert.equal(args[args.indexOf('--config') + 1], path.join(directory, '.wakatime.cfg'));
    assert.match(args[args.indexOf('--plugin') + 1], /^opencode2-cli\/0.0.0-beta-19289 /);
    assert.equal(extra.length, 2);
    assert.equal(extra[1].entity, path.join(directory, 'renamed.ts'));
    assert.equal(extra[1].ai_line_changes, 1);
    assert.ok(extra.every((item) => item.category === 'ai coding' && item.is_write));
    assert.ok(!fs.readFileSync(capture, 'utf8').includes('SECRET'));
    assert.ok(!args.includes('--key'));
  } finally {
    if (oldHome === undefined) delete process.env.WAKATIME_HOME; else process.env.WAKATIME_HOME = oldHome;
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('missing WakaTime CLI never fails a tool or cleanup', async () => {
  const directory = temporary();
  const oldHome = process.env.WAKATIME_HOME;
  process.env.WAKATIME_HOME = directory;
  try {
    const { callback, dispose } = await tracker(directory, path.join(directory, 'missing-cli'));
    await callback({ sessionID: 'test', id: 'test', tool: 'read', status: 'completed', input: { path: 'test.ts' } });
    await dispose();
    assert.match(fs.readFileSync(path.join(directory, 'opencode2.log'), 'utf8'), /unavailable/);
  } finally {
    if (oldHome === undefined) delete process.env.WAKATIME_HOME; else process.env.WAKATIME_HOME = oldHome;
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
