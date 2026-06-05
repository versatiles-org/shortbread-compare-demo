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
MBTILES="$DATA_DIR/shortbread.mbtiles"
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
  --output="$MBTILES" \
  $PLANETILER_EXTRA_FLAGS

echo ">>> Converting to a VersaTiles container"
versatiles convert "$MBTILES" "$CONTAINER"

echo ">>> Done:"
ls -lh "$MBTILES" "$CONTAINER"
echo ">>> Next: ./03-serve.sh"
