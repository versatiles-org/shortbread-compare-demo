# Shared configuration for the Shortbread 1.1 comparison demo.
# Sourced by every NN-*.sh step. Override any value via the environment.

# --- repo / build ---
export REPO_URL="${REPO_URL:-https://github.com/versatiles-org/planetiler.git}"
export BRANCH="${BRANCH:-feature/shortbread-java-profile}"
# All build artifacts live in a gitignored data/ folder inside this repo by default.
# ${BASH_SOURCE[0]} resolves to config.sh regardless of which NN-*.sh step sourced it.
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WORKDIR="${WORKDIR:-$CONFIG_DIR/data}"
export REPO_DIR="${REPO_DIR:-$WORKDIR/planetiler}"
export DATA_DIR="${DATA_DIR:-$WORKDIR/data}"
export FRONTEND_DIR="${FRONTEND_DIR:-$WORKDIR/frontend}"

# --- tile generation ---
# AREA=planet builds worldwide tiles. Use a Geofabrik region name (e.g. "monaco", "germany")
# for a quick smoke test before committing to the full planet run.
export AREA="${AREA:-planet}"
export LANGUAGES="${LANGUAGES:-en,fr,es,de,ar,el,it,nl,pl,pt,uk}"

# Beyond-spec Shortbread experiments (planetiler --shortbread_experiments). Opt-in features
# that go past the 1.0/1.1 spec; default is "all" to exercise everything. Set to "none" for
# strict-spec output, or a comma-separated subset of:
#   building_heights  — 3D building height/min_height attributes on the buildings layer
#   building_parts    — Simple-3D-Buildings building:part polygons + hide_3d flag (implies building_heights)
#   locale_names      — geofenced name_<lang> fallback inside matching countries (adds Natural Earth admin_0 source)
#   island_labels     — place_labels for islands mapped as polygons (not just nodes)
#   address_details   — addr:unit and addr:block attributes on the addresses layer
#   bridge_names      — name attribute on bridge polygons
export EXPERIMENTS="${EXPERIMENTS:-all}"

# JVM heap. Planetiler keeps most data off-heap, so this can stay modest even for the planet.
export JAVA_OPTS="${JAVA_OPTS:--Xmx20g}"

# Extra planetiler flags. For a planet build on a machine without huge RAM, memory-mapped
# storage avoids OOM (at the cost of needing a fast SSD and more disk). Remove on big-RAM hosts.
# See the repo's PLANET.md for tuning guidance.
export PLANETILER_EXTRA_FLAGS="${PLANETILER_EXTRA_FLAGS:---nodemap_type=array --storage=mmap}"

# --- serving ---
export PORT="${PORT:-8080}"
# Name the local tile source is mounted under (URL becomes /tiles/$SOURCE_ID/...).
export SOURCE_ID="${SOURCE_ID:-shortbread}"

# --- low-zoom land cover (issue #1) ---
# ESA WorldCover land cover (versatiles-org/landcover-vectors), feature-merged into the
# generated Shortbread container by 04-merge.sh (VPL from_merged_vector) so the right map
# isn't blank at low zoom where OSM has no land detail yet. It's read straight from this
# remote container (no local download — versatiles range-reads it on demand).
#
# As of landcover-vectors v2 the container no longer has its own `landcover-vectors` layer:
# its features are written into Shortbread's *own* `land` and `water_polygons` layers using
# standard Shortbread `kind` values, so from_merged_vector folds them straight into the
# matching Shortbread layers and a stock Shortbread style draws them with no extra rules (the
# frontend no longer adds a custom land-cover layer). Set LANDCOVER_URL="" to skip the merge.
# (no colon, so an explicit LANDCOVER_URL="" disables the merge rather than re-defaulting)
#
# This must point at a *v2* container. While v2 is still being tested it's served from the
# Hetzner storage box over SFTP (port 23) — versatiles range-reads it on demand, same as an
# http(s) URL. Swap this for https://download.versatiles.org/landcover.versatiles once v2 is
# published there. SFTP auth uses your SSH key (agent / ~/.ssh/config / default keys) or
# VERSATILES_SSH_IDENTITY; embed a password as sftp://user:pass@host if you must.
export LANDCOVER_URL="${LANDCOVER_URL-sftp://u417480@u417480.your-storagebox.de:23/home/incoming/landcover.versatiles}"

# Remote Shortbread tiles used by the *preview* step (03-preview.sh) only. The preview serves a
# realtime VPL merge of these remote Shortbread tiles + the remote land cover above, so you can
# eyeball the merged result over SFTP without first building the local container (04-merge.sh).
export REMOTE_SHORTBREAD_URL="${REMOTE_SHORTBREAD_URL-sftp://u417480@u417480.your-storagebox.de:23/home/incoming/shortbread.pmtiles}"

# Download (once) the standard versatiles-frontend tarball into $WORKDIR, reusing any existing
# copy, and set FRONTEND_TAR to its path. The preview (03) and serve (05) steps both layer the
# repo's frontend/ (with its comparison index.html) on top of this tarball.
prepare_frontend() {
  mkdir -p "$WORKDIR"
  FRONTEND_TAR="$WORKDIR/frontend.tar.gz"
  if [ -f "$FRONTEND_TAR" ]; then
    echo "    reusing existing $FRONTEND_TAR (delete it to force a fresh download)"
    return 0
  fi
  # the standard (uncompressed) frontend.tar.gz from the latest versatiles-frontend release
  local asset_url
  asset_url="$(curl -fsSL https://api.github.com/repos/versatiles-org/versatiles-frontend/releases/latest \
    | jq -r '.assets[].browser_download_url | select(test("/frontend\\.tar.gz$"))' | head -1)"
  if [ -z "$asset_url" ]; then
    echo "Could not find frontend.tar.gz in the latest versatiles-frontend release." >&2
    echo "See https://github.com/versatiles-org/versatiles-frontend/releases" >&2
    return 1
  fi
  echo "    downloading $asset_url"
  curl -fsSL "$asset_url" -o "$FRONTEND_TAR"
}
