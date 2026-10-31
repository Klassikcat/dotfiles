# OpenCode V2 profile

`opencode2` uses the launcher in `bin/opencode2`, which sets
`OPENCODE_CONFIG_DIR=$HOME/.config/opencode2` for V2 only.
The upstream executable stays at `~/.opencode/bin/opencode2` for upgrades.
The sibling `bin/opencode` launcher explicitly selects the original V1
directory, including when invoked from a shell that inherited V2's environment.

`~/.config/opencode/cli.json` is a symlink to this profile's `cli.json`.
That filename belongs to V2, despite the legacy directory name; V1 uses
`tui.json`. The symlink ensures a direct invocation of the upstream V2
binary also reads the V2 terminal plugin list. The old CLI file is backed
up as `cli-before-profile-link.json.backup`.

## Plugin locations

| | V1 (`opencode`) | V2 (`opencode2`) |
| --- | --- | --- |
| Global config | `~/.config/opencode/opencode.json` | `~/.config/opencode2/opencode.json` |
| Local server plugins | `~/.config/opencode/plugins/` | `~/.config/opencode2/plugins/` |
| Package plugin list | `plugin` in V1 config | `plugins` in V2 config |
| Terminal plugin list | Existing V1 configuration | `~/.config/opencode2/cli.json` |

V2 includes the context-collection plugin (`explore`, `librarian`,
`multimodal-looker`) plus native Ponytail and WakaTime integrations.
Add future V2 plugins to this profile.

## Ponytail + WakaTime (native V2 ports)

Validated on `opencode2 0.0.0-beta-19289`. These are default-export
`{ id, setup(ctx) }` plugins, not V1 hook objects. Local files auto-load;
no package-list entry or V1 config change is required.

- `plugins/ponytail-v2.js`: injects instructions on `session.hook("context")`.
  Default is **full**. `/ponytail lite|full|ultra|review|off` changes the mode;
  `/ponytail status` checks it. Switching costs no model call and takes effect
  on the next generation, including subagents. State is profile-wide, shared
  across V2 sessions, in this directory's `.ponytail-active`, independent of V1.
  `/ponytail-review`, `-help`, `-gain`, `-debt`, and `-audit` submit the upstream
  command prompts. All six upstream skills are registered too.
- `vendor/ponytail-4.9.0/`: pinned upstream instruction builder, config helper,
  commands, skills and MIT license. Copied locally so cache cleanup or an npm
  update cannot break the port. Upstream default-mode environment/config
  resolution is retained when the V2 state file is absent.
- `plugins/wakatime-v2.js`: observes successful native `tool.hook("execute.after")`
  calls for read/write/edit/patch, including nested calls. Resolves relative
  paths against the V2 working directory, uses native file diffs for line
  counts, skips directories/failed tools, deduplicates call IDs, and batches
  pending file activity at 60-second intervals with an initial 1-second delay.
  Idle/deletion/disposal also flush pending activity. No prompt, file contents,
  shell command text or API key is included in heartbeat arguments.
  The editor identifier is `opencode2-cli/<version>`, category **ai coding**.
  Idle chat without file-tool activity is not tracked.

WakaTime reuses `~/.wakatime/wakatime-cli` and `~/.wakatime.cfg`; existing
privacy/exclusion settings and the CLI's offline queue remain in effect.
`WAKATIME_HOME` and `WAKATIME_CLI_PATH` are supported. The CLI is not downloaded
at startup; if missing, coding continues and `~/.wakatime/opencode2.log` records
an error. CLI failures are non-fatal; pending batches handed to a missing or
killed CLI are not retained by the plugin. Normal network retries/offline
storage are handled by the installed CLI. Detailed CLI logs: `~/.wakatime/wakatime.log`.

Verification:

```bash
node --test ~/.config/opencode2/tests/integrations.test.mjs
opencode2 plugin list
opencode2 api GET /api/plugin  # both IDs should have state.status = active
```

Checked: unit tests, real V2 plugin/command/skill registration, native mode
switches on an isolated test server, and a real WakaTime CLI heartbeat (exit 0).
The unit tests mock model callbacks and CLI transport; no paid model generation
was used for verification. Node syntax checks and the final changed-file LSP
diagnostics sweep passed; this is a standalone JS profile, not a typed SDK project.

The running service hot-loads these files. If an existing TUI does not refresh
its slash-command list, reopen it. To disable a port, move its `.js` file outside
`plugins/`; there is no V1 configuration to roll back. Review compatibility
after future V2 beta upgrades.

Model/provider and MCP settings were copied from V1 when this profile was
created. Subsequent edits to either config are independent. The `agent`,
`agents`, and `commands` directories link to the existing definitions to
preserve the user's custom agents and commands.

This separates global plugin discovery. Project-local `opencode.json(c)`
and `.opencode/plugins/` still follow each version's normal discovery rules.
In particular, launching inside the V1 config folder can load its
`opencode.json` as a project config.

## Activate

Open a new terminal (Bash and Nushell launchers are configured). Exit old
OpenCode V2 TUI processes first: an already-running client can recreate the
server with the profile captured when that client started.

In Bash:

```bash
source ~/.bashrc
opencode2 service restart
```

In Nushell, open a new terminal and run:

```nu
opencode2 service restart
opencode2 --continue
```

The V2 service also needs its own persisted environment; the launcher's
environment alone does not configure an already-running service. Both
`~/.config/opencode/service.json` and this profile's `service.json` store
`env.OPENCODE_CONFIG_DIR` pointing at this V2 profile. These are V2 service
settings, not V1 plugin settings. They are managed through
`opencode2 service set env OPENCODE_CONFIG_DIR "$HOME/.config/opencode2"`.

The launcher selects V2's CLI settings too. Direct invocations use the
default `cli.json` symlink above, so both entrypoints share the same V2
terminal plugin list.
