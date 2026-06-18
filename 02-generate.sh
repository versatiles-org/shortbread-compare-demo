#!/usr/bin/env bash
#
# 02-generate.sh — generate Shortbread 1.1 vector tiles with planetiler.
#
# This step only runs planetiler and writes the raw PMTiles. The land-cover merge and the
# final brotli VersaTiles container are produced separately by 04-merge.sh, so a slow planet
# build isn't repeated every time you re-merge or re-tune the land cover.
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
# Tiles are written as PMTiles rather than MBTiles: PMTiles is a flat, sequentially-laid-out
# file, so the `versatiles convert` read in 04-merge.sh avoids the random-access SQLite B-tree
# overhead that makes reading MBTiles slow (planetiler picks the format from the file
# extension). To override the location — e.g. a ramdisk for small test areas — set TILES.
PMTILES="${TILES:-$DATA_DIR/osm.pmtiles}"
VERSATILES="${VERSATILES:-$DATA_DIR/osm.versatiles}"

echo ">>> Generating Shortbread 1.1 tiles for area='$AREA' (languages: $LANGUAGES)"
# Run from WORKDIR so planetiler caches downloads under $WORKDIR/data/sources.
cd "$WORKDIR"
# shellcheck disable=SC2086
java $JAVA_OPTS -jar "$JAR" shortbread-1.1 \
  --area="$AREA" \
  --download \
  --force \
  --name_languages="$LANGUAGES" \
  --output="$PMTILES" \
  $PLANETILER_EXTRA_FLAGS

versatiles convert -c brotli "$PMTILES" "$VERSATILES"

echo ">>> Done:"
ls -lh "$PMTILES"
ls -lh "$VERSATILES"
echo ">>> Next: ./03-preview.sh (quick realtime-merged preview) or ./04-merge.sh (build the final container)"
