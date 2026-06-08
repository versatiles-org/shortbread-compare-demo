#!/usr/bin/env bash
#
# 03-serve.sh — serve the generated tiles with versatiles, using the standard VersaTiles
# frontend as the static source but with index.html replaced by the split comparison map.
#
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

CONTAINER="$DATA_DIR/shortbread.versatiles"
if [ ! -f "$CONTAINER" ]; then
  echo "Tile container not found ($CONTAINER) — run ./02-generate.sh first." >&2
  exit 1
fi

echo ">>> Preparing the static frontend"
mkdir -p "$FRONTEND_DIR"
# download the standard (uncompressed) frontend.tar.gz from the latest versatiles-frontend release
asset_url="$(curl -fsSL https://api.github.com/repos/versatiles-org/versatiles-frontend/releases/latest \
  | jq -r '.assets[].browser_download_url | select(test("/frontend\\.tar.gz$"))' | head -1)"
if [ -z "$asset_url" ]; then
  echo "Could not find frontend.tar.gz in the latest versatiles-frontend release." >&2
  echo "See https://github.com/versatiles-org/versatiles-frontend/releases" >&2
  exit 1
fi
echo "    downloading $asset_url"
curl -fsSL "$asset_url" -o "$WORKDIR/frontend.tar.gz"

echo ">>> Starting versatiles server on http://0.0.0.0:$PORT"
echo "    left half  = current OSM Shortbread tiles from tiles.versatiles.org"
echo "    right half = locally generated planetiler Shortbread 1.1 tiles"
exec versatiles serve \
  --port "$PORT" \
  --static "$WORKDIR/frontend.tar.gz" \
  "${SOURCE_ID}:${CONTAINER}"
