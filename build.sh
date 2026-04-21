#!/usr/bin/env bash
# Build a vibepod/claude-based image with portable ~/.claude config baked in.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${CLAUDE_HOME:-$HOME/.claude}"
STAGE="$HERE/staging/claude-defaults"
IMAGE="${IMAGE:-claude-custom:latest}"

if [ ! -d "$SRC" ]; then
    echo "No config dir at $SRC" >&2
    exit 1
fi

rm -rf "$HERE/staging"
mkdir -p "$STAGE"

# Portable bits only. Exclude per-machine runtime state and anything
# with secrets/session data.
rsync -a \
    --exclude='projects/' \
    --exclude='sessions/' \
    --exclude='session-env/' \
    --exclude='todos/' \
    --exclude='tasks/' \
    --exclude='cache/' \
    --exclude='file-history/' \
    --exclude='paste-cache/' \
    --exclude='shell-snapshots/' \
    --exclude='backups/' \
    --exclude='telemetry/' \
    --exclude='statsig/' \
    --exclude='history.jsonl' \
    --exclude='mcp-needs-auth-cache.json' \
    --exclude='settings.json.bak' \
    --exclude='plugins/cache/agentmemory/' \
    "$SRC"/ "$STAGE"/

# Rewrite absolute host paths in settings.json so hooks resolve inside
# the container (CLAUDE_CONFIG_DIR=/claude).
if [ -f "$STAGE/settings.json" ]; then
    python3 - "$STAGE/settings.json" "$SRC" <<'PY'
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
host = sys.argv[2].rstrip('/')
text = path.read_text().replace(host, '/claude')
data = json.loads(text)
# Drop agentmemory — not used in the container and not installed.
data.get('enabledPlugins', {}).pop('agentmemory@agentmemory', None)
data.get('extraKnownMarketplaces', {}).pop('agentmemory', None)
path.write_text(json.dumps(data, indent=2) + '\n')
PY
fi

# Drop agentmemory plugin files if present.
rm -rf "$STAGE/plugins/repos/agentmemory" \
       "$STAGE/plugins/marketplaces/agentmemory" \
       "$STAGE/plugins/cache/agentmemory" 2>/dev/null || true

echo "Staged $(du -sh "$STAGE" | cut -f1) of config"

docker build -t "$IMAGE" "$HERE"

echo
echo "Built $IMAGE"
echo "Run with:"
echo "  docker run --rm -it -v \"\$PWD\":/workspace $IMAGE"
