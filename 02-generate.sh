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

# For AREA=planet, pre-download the planet .osm.pbf over BitTorrent (fast) and feed it to
# planetiler via --osm_path instead of letting planetiler HTTP-download it (slow). The other
# sources (ocean water-polygons, natural earth) are still fetched by planetiler's --download.
# planetiler caches downloads under $WORKDIR/data/sources, so we drop the planet pbf there too.
SOURCES_DIR="$DATA_DIR/sources"
OSM_PATH_ARG=""
if [ "$AREA" = "planet" ] && [ "$USE_TORRENT" = "1" ]; then
  if ! command -v aria2c >/dev/null; then
    echo "aria2c not found — install it (./01-setup.sh) or set USE_TORRENT=0 to use planetiler's HTTP download." >&2
    exit 1
  fi
  mkdir -p "$SOURCES_DIR"
  if [ -z "$PLANET_DATE" ]; then
    echo ">>> Resolving latest planet snapshot from $PLANET_PBF_BASE/"
    PLANET_DATE="$(curl -fsSL "$PLANET_PBF_BASE/" \
      | grep -oE 'planet-[0-9]{6}\.osm\.pbf' | grep -oE '[0-9]{6}' | sort | tail -n1)"
  fi
  if [ -z "$PLANET_DATE" ]; then
    echo "Could not determine the latest planet date from $PLANET_PBF_BASE/ — set PLANET_DATE=YYMMDD." >&2
    exit 1
  fi
  PLANET_PBF="$SOURCES_DIR/planet-$PLANET_DATE.osm.pbf"
  if [ -f "$PLANET_PBF" ] && [ ! -f "$PLANET_PBF.aria2" ]; then
    echo ">>> Reusing existing $PLANET_PBF (delete it to force a fresh download)"
  else
    echo ">>> Downloading planet-$PLANET_DATE.osm.pbf via BitTorrent (aria2c)"
    TORRENT="$SOURCES_DIR/planet-$PLANET_DATE.osm.pbf.torrent"
    curl -fsSL "$PLANET_PBF_BASE/planet-$PLANET_DATE.osm.pbf.torrent" -o "$TORRENT"
    # --seed-time=0: stop seeding the moment the download finishes. --continue + the .aria2
    # control file make this resumable. falloc preallocates the ~80 GB file quickly on
    # ext4/xfs/btrfs (the Debian build host); switch to none if your filesystem lacks fallocate.
    aria2c --dir="$SOURCES_DIR" --seed-time=0 --continue=true \
      --file-allocation=falloc --summary-interval=30 "$TORRENT"
  fi
  OSM_PATH_ARG="--osm_path=$PLANET_PBF"
fi

echo ">>> Generating Shortbread 1.1 tiles for area='$AREA' (languages: $LANGUAGES, experiments: $EXPERIMENTS)"
# Run from WORKDIR so planetiler caches downloads under $WORKDIR/data/sources.
cd "$WORKDIR"
# shellcheck disable=SC2086
java $JAVA_OPTS -jar "$JAR" shortbread-1.1 \
  --area="$AREA" \
  --download \
  --force \
  --name_languages="$LANGUAGES" \
  --shortbread_experiments="$EXPERIMENTS" \
  $OSM_PATH_ARG \
  --output="$PMTILES" \
  $PLANETILER_EXTRA_FLAGS

versatiles convert -c brotli "$PMTILES" "$VERSATILES"

echo ">>> Done:"
ls -lh "$PMTILES"
ls -lh "$VERSATILES"
echo ">>> Next: ./03-preview.sh (quick realtime-merged preview) or ./04-merge.sh (build the final container)"
