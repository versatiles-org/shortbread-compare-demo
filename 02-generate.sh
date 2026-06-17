#!/usr/bin/env bash
#
# 02-generate.sh — generate Shortbread 1.1 vector tiles with planetiler and convert the
# result into a VersaTiles container.
#
# Resource note for AREA=planet: planetiler downloads the full planet OSM extract (~80 GB)
# plus the ocean water-polygons shapefile, and needs a large machine — budget roughly
# 64 GB+ RAM (or memory-mapped storage on a fast SSD), ~400 GB+ free disk, and a few hours.
# Test with a small AREA first, e.g.  AREA=monaco ./02-generate.sh
#
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

JAR="$(ls "$REPO_DIR"/planetiler-dist/target/*with-deps*.jar 2>/dev/null | head -1 || true)"
if [ -z "$JAR" ]; then
  echo "Distribution jar not found — run ./01-setup.sh first." >&2
  exit 1
fi

mkdir -p "$DATA_DIR"
# Intermediate tiles are written as PMTiles rather than MBTiles: PMTiles is a flat,
# sequentially-laid-out file, so the `versatiles convert` read below avoids the random-access
# SQLite B-tree overhead that makes reading MBTiles slow (planetiler picks the format from the
# file extension). To override the location — e.g. a ramdisk for small test areas — set TILES.
TILES="${TILES:-$DATA_DIR/shortbread.pmtiles}"
CONTAINER="$DATA_DIR/shortbread.versatiles"

echo ">>> Generating Shortbread 1.1 tiles for area='$AREA' (languages: $LANGUAGES)"
# Run from WORKDIR so planetiler caches downloads under $WORKDIR/data/sources.
cd "$WORKDIR"
# shellcheck disable=SC2086
java $JAVA_OPTS -jar "$JAR" shortbread-1.1 \
  --area="$AREA" \
  --download \
  --force \
  --name_languages="$LANGUAGES" \
  --output="$TILES" \
  $PLANETILER_EXTRA_FLAGS

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
  echo ">>> Converting to a brotli VersaTiles container"
  versatiles convert -c brotli "$TILES" "$CONTAINER"
fi

echo ">>> Done:"
ls -lh "$TILES" "$CONTAINER"
echo ">>> Next: ./03-serve.sh"
