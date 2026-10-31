import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const profile = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const vendor = path.join(profile, 'vendor/ponytail-4.9.0');
const { getPonytailInstructions } = require(path.join(vendor, 'hooks/ponytail-instructions.js'));
const { getDefaultMode, normalizePersistedMode } = require(path.join(vendor, 'hooks/ponytail-config.js'));
const { parseCommandFile } = require(path.join(vendor, '.opencode/plugins/ponytail-frontmatter.cjs'));

// Native OpenCode V2 API; skill registration uses the 2.0.16 Skill.Info shape.
export default {
  id: 'ponytail-v2',
  async setup(ctx) {
    const statePath = ctx.options?.statePath ?? path.join(profile, '.ponytail-active');
    const readMode = () => {
      try {
        return normalizePersistedMode(fs.readFileSync(statePath, 'utf8').trim()) ?? getDefaultMode();
      } catch {
        return getDefaultMode();
      }
    };
    await ctx.session.hook('context', (event) => {
      const mode = readMode();
      if (mode !== 'off') {
        event.system.push({ type: 'text', text: getPonytailInstructions(mode) });
      }
    });
    await ctx.command.transform((editor) => {
      editor.add({
        name: 'ponytail',
        description: 'Ponytail mode: lite | full | ultra | review | off | status',
        async execute(invocation) {
          const args = String(invocation.prompt?.text ?? '').trim();
          const mode = args === 'status' ? readMode() : args ? normalizePersistedMode(args) : getDefaultMode();
          if (!mode) throw new Error('Usage: /ponytail lite|full|ultra|review|off|status');
          if (args !== 'status') {
            fs.mkdirSync(path.dirname(statePath), { recursive: true });
            // Unique temp file + rename keeps concurrent sessions from seeing partial writes.
            const temporary = `${statePath}.${process.pid}.${crypto.randomUUID()}.tmp`;
            fs.writeFileSync(temporary, mode, { mode: 0o600 });
            fs.renameSync(temporary, statePath);
          }
          // No model call just to change mode. Applies to the very next generation.
          await ctx.session.synthetic({ sessionID: invocation.sessionID, text: `Ponytail: ${mode}`, resume: false });
        },
      });
      const directory = path.join(vendor, '.opencode/command');
      for (const file of fs.readdirSync(directory).filter((name) => name.endsWith('.md') && name !== 'ponytail.md')) {
        const command = parseCommandFile(path.join(directory, file));
        if (!command) continue;
        editor.add({
          name: path.basename(file, '.md'),
          description: command.description,
          async execute(invocation) {
            const args = invocation.prompt?.text ?? '';
            const text = command.template.includes('$ARGUMENTS')
              ? command.template.replaceAll('$ARGUMENTS', () => args)
              : [command.template, args].filter(Boolean).join('\n\n');
            await ctx.session.prompt({
              ...invocation.prompt,
              sessionID: invocation.sessionID,
              text,
              delivery: invocation.delivery,
            });
          },
        });
      }
    });
    await ctx.skill.transform((editor) => {
      const directory = path.join(vendor, 'skills');
      for (const name of fs.readdirSync(directory)) {
        const location = path.join(directory, name, 'SKILL.md');
        if (!fs.existsSync(location)) continue;
        const skill = parseCommandFile(location);
        if (!skill) continue;
        editor.add({ id: name, name, description: skill.description ?? name, path: location, content: skill.template });
      }
    });
  },
};
