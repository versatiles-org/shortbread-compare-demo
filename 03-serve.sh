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
# download the standard (uncompressed) frontend.tar from the latest versatiles-frontend release
asset_url="$(curl -fsSL https://api.github.com/repos/versatiles-org/versatiles-frontend/releases/latest \
  | jq -r '.assets[].browser_download_url | select(test("/frontend\\.tar$"))' | head -1)"
if [ -z "$asset_url" ]; then
  echo "Could not find frontend.tar in the latest versatiles-frontend release." >&2
  echo "See https://github.com/versatiles-org/versatiles-frontend/releases" >&2
  exit 1
fi
echo "    downloading $asset_url"
curl -fsSL "$asset_url" -o "$WORKDIR/frontend.tar"
rm -rf "$FRONTEND_DIR"
mkdir -p "$FRONTEND_DIR"
tar -xf "$WORKDIR/frontend.tar" -C "$FRONTEND_DIR"

echo ">>> Installing the custom split-comparison index.html"
# SOURCE_ID is injected so the page knows the local tile URL (/tiles/$SOURCE_ID/...).
sed "s|__SOURCE_ID__|$SOURCE_ID|g" "$(dirname "$0")/frontend/index.html" > "$FRONTEND_DIR/index.html"

echo ">>> Starting versatiles server on http://0.0.0.0:$PORT"
echo "    left half  = current OSM Shortbread tiles from tiles.versatiles.org"
echo "    right half = locally generated planetiler Shortbread 1.1 tiles"
exec versatiles serve \
  --port "$PORT" \
  --static "$FRONTEND_DIR" \
  "${SOURCE_ID}:${CONTAINER}"
