#!/usr/bin/env bash
#
# 03-preview.sh — quick preview of the merged map *without* building the final container.
#
# Instead of a pre-built local container, this serves an inline VPL pipeline that
# feature-merges the remote Shortbread tiles and the remote ESA WorldCover land cover on the
# fly (versatiles range-reads both over SFTP and merges per request). That lets you eyeball the
# land-cover merge / styling before committing to the slow 04-merge.sh build. The two remote
# sources are $REMOTE_SHORTBREAD_URL and $LANDCOVER_URL (see config.sh).
#
# Note: this previews the *remote* Shortbread tiles on the storage box, not the local PMTiles
# from 02-generate.sh — upload your tiles there (or point REMOTE_SHORTBREAD_URL elsewhere) to
# preview your own build. Realtime SFTP merges are slower than serving the built container, so
# this is for spot-checking, not load.
#
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

echo ">>> Preparing the static frontend"
prepare_frontend

# Inline VPL pipeline, named "$SOURCE_ID" so it serves at /tiles/$SOURCE_ID/ exactly like the
# built container does — the frontend's right map points there either way. `from_merged_vector`
# combines features per layer name, so the land cover's `land`/`water_polygons` features
# (landcover-vectors v2) fold straight into Shortbread's own layers.
PREVIEW_SOURCE="[${SOURCE_ID},vpl](from_merged_vector [ from_container filename=\"${REMOTE_SHORTBREAD_URL}\", from_container filename=\"${LANDCOVER_URL}\" ])"

echo ">>> Starting versatiles PREVIEW server on http://0.0.0.0:$PORT"
echo "    left half  = Shortbread via tilemaker (tiles.versatiles.org)"
echo "    right half = remote Shortbread + ESA WorldCover, merged in realtime over SFTP"
echo "    shortbread: $REMOTE_SHORTBREAD_URL"
echo "    land cover: $LANDCOVER_URL"
exec versatiles serve \
  --port "$PORT" \
  --static "frontend/" \
  --static "$FRONTEND_TAR" \
  "$PREVIEW_SOURCE"
