# claude-docker

A Docker image that bundles [Claude Code](https://claude.com/claude-code) with a portable copy of your local `~/.claude` config, plus the language servers and CLI tools I actually use day-to-day.

## What

Builds on top of `vibepod/claude:latest` and adds:

- **Language servers**: `rust-analyzer`, `gopls`, `typescript-language-server` (+ `node`, `tsc`, `tsserver`)
- **CLIs**: [`rtk`](https://github.com/rtk-ai/rtk) (token-killer proxy) and [`allium`](https://crates.io/crates/allium-cli)
- **Your config, baked in**: `build.sh` snapshots `~/.claude` into the image (minus per-machine runtime state and anything with secrets/session data) so slash commands, skills, hooks, and settings travel with the container.

On first run the entrypoint seeds `CLAUDE_CONFIG_DIR` (default `/claude`) from the baked defaults, so mounting a volume there still works — the volume gets populated on first use and persists across runs.

## Why

Running Claude Code in a container gives me:

- A clean, reproducible sandbox for `--dangerously-skip-permissions` work that won't touch my host.
- The same editor-grade tooling (LSPs) inside the container that the host has, so Claude can read types and jump to defs.
- A portable version of my personal Claude setup — drop the image on any machine (or a remote box) and I get my skills, agents, hooks, and permissions without re-syncing dotfiles.

## Build

```bash
./build.sh
```

Honors `CLAUDE_HOME` (defaults to `~/.claude`) and `IMAGE` (defaults to `claude-custom:latest`).

The staging step excludes `projects/`, `sessions/`, `todos/`, caches, telemetry, history, and the `agentmemory` plugin. Absolute host paths in `settings.json` are rewritten to `/claude` so hooks resolve inside the container.

## Run

```bash
docker run --rm -it -v "$PWD":/workspace claude-custom:latest
```

To persist config across runs, mount a volume at `/claude`:

```bash
docker run --rm -it \
  -v "$PWD":/workspace \
  -v claude-config:/claude \
  claude-custom:latest
```

## Layout

- `Dockerfile` — multi-stage build: Rust tools, Go tools, Node tools, then final image.
- `build.sh` — stages a portable copy of `~/.claude` into `staging/claude-defaults/` and runs `docker build`.
- `entrypoint-wrapper.sh` — seeds `/claude` from `/claude-defaults` on first run, then execs the upstream entrypoint.
