# Global rules

## Local Tilt stacks: never `go run` long-lived servers

- In any Tiltfile (`dev/**/Tiltfile`, e.g. `dev/wikiwiki-local`, `dev/wikiwiki-provision-agent`), do not start Go servers with `serve_cmd='go run ./cmd/server'` (or any `go run` for a long-running process). Every Tilt restart leaks a ~200MB `/tmp/go-build<N>` dir; `/tmp` is a tmpfs with a ~25GB per-user quota and filling it breaks every Go build ("disk quota exceeded") and takes the QA backend down.
- Build first, then exec the binary, e.g. `serve_cmd='go build -o .tilt-bin/server ./cmd/server && exec ./.tilt-bin/server'` (run from the backend dir; keep `serve_dir`/`serve_env` as they were). Make sure the output dir is git-ignored (add `.tilt-bin/` to the backend `.gitignore` if missing). Use `exec` so Tilt's stop signal reaches the server.
- When you touch a Tiltfile that still uses `go run` for a server, convert it in the same change and mention it in your summary.
- If `/tmp` is already near quota (`quota -s`), delete only `/tmp/go-build*` dirs not referenced by a live process (`/proc/*/exe`, `cwd`, `fd`) — never ones in use.
