#!/bin/sh
# Seed CLAUDE_CONFIG_DIR from baked defaults on first run, then hand off
# to the upstream vibepod entrypoint.
set -eu

CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-/claude}"
DEFAULTS_DIR="/claude-defaults"

mkdir -p "$CLAUDE_CONFIG_DIR"

if [ -d "$DEFAULTS_DIR" ] && [ -z "$(ls -A "$CLAUDE_CONFIG_DIR" 2>/dev/null || true)" ]; then
    cp -a "$DEFAULTS_DIR/." "$CLAUDE_CONFIG_DIR/"
fi

exec /usr/local/bin/entrypoint.sh "$@"
