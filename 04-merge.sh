#!/usr/bin/env bash
#
# 04-merge.sh — merge the ESA WorldCover land cover into the planetiler Shortbread tiles and
# pack the result into the final brotli VersaTiles container served by 05-serve.sh.
#
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

TILES="${TILES:-$DATA_DIR/shortbread.pmtiles}"
CONTAINER="$DATA_DIR/shortbread.versatiles"

if [ ! -f "$TILES" ]; then
  echo "Planetiler tiles not found ($TILES) — run ./02-generate.sh first." >&2
  exit 1
fi

# Convert to a brotli VersaTiles container. When LANDCOVER_URL is set (issue #1), merge the
# ESA WorldCover land cover into the same Shortbread output with the VPL `from_merged_vector`
# operation. from_merged_vector combines features per layer name: with a landcover-vectors v2
# container its `land`/`water_polygons` features (standard Shortbread `kind` values) fold into
# the Shortbread `land`/`water_polygons` layers, so each output tile gains low-zoom land cover
# within the existing Shortbread schema — a stock style draws it, no extra layer needed. The
# land cover container is read straight from its remote URL via `from_container`, so nothing is
# downloaded locally — versatiles range-reads it on demand. Set LANDCOVER_URL="" to skip it.
if [ -n "${LANDCOVER_URL:-}" ]; then
  echo ">>> Merging Shortbread tiles + ESA WorldCover land cover into a brotli container (VPL from_merged_vector)"
  echo "    land cover source: $LANDCOVER_URL"
  versatiles convert -c brotli \
    "[,vpl](from_merged_vector [ from_container filename=\"$TILES\", from_container filename=\"$LANDCOVER_URL\" ])" \
    "$CONTAINER"
else
  echo ">>> Converting to a brotli VersaTiles container (no land cover; LANDCOVER_URL is empty)"
  versatiles convert -c brotli "$TILES" "$CONTAINER"
fi

echo ">>> Done:"
ls -lh "$TILES" "$CONTAINER"
echo ">>> Next: ./05-serve.sh"
