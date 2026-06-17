#!/usr/bin/env bash
#
# 05-serve.sh — serve the final merged tiles with versatiles, using the standard VersaTiles
# frontend as the static source but with index.html replaced by the split comparison map.
#
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

CONTAINER="$DATA_DIR/shortbread.versatiles"
if [ ! -f "$CONTAINER" ]; then
  echo "Tile container not found ($CONTAINER) — run ./04-merge.sh first." >&2
  exit 1
fi

echo ">>> Preparing the static frontend"
prepare_frontend

# The local container already includes the ESA WorldCover land cover (merged in by 04-merge.sh
# via VPL from_merged_vector), so a single local source serves the right map.
echo ">>> Starting versatiles server on http://0.0.0.0:$PORT"
echo "    left half  = Shortbread via tilemaker (tiles.versatiles.org)"
echo "    right half = Shortbread via native planetiler integration + ESA WorldCover (local)"
exec versatiles serve \
  --port "$PORT" \
  --static "frontend/" \
  --static "$FRONTEND_TAR" \
  "[${SOURCE_ID}]${CONTAINER}"
