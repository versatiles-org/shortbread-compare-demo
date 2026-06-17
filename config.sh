# Shared configuration for the Shortbread 1.1 comparison demo.
# Sourced by 01-setup.sh, 02-generate.sh and 03-serve.sh. Override any value via the environment.

# --- repo / build ---
export REPO_URL="${REPO_URL:-https://github.com/versatiles-org/planetiler.git}"
export BRANCH="${BRANCH:-feature/shortbread-java-profile}"
export WORKDIR="${WORKDIR:-$HOME/shortbread-demo}"
export REPO_DIR="${REPO_DIR:-$WORKDIR/planetiler}"
export DATA_DIR="${DATA_DIR:-$WORKDIR/data}"
export FRONTEND_DIR="${FRONTEND_DIR:-$WORKDIR/frontend}"

# --- tile generation ---
# AREA=planet builds worldwide tiles. Use a Geofabrik region name (e.g. "monaco", "germany")
# for a quick smoke test before committing to the full planet run.
export AREA="${AREA:-planet}"
export LANGUAGES="${LANGUAGES:-en,fr,es,de,ar,el,it,nl,pl,pt,uk}"

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
# generated Shortbread container by 02-generate.sh (VPL from_merged_vector) so the right map
# isn't blank at low zoom where OSM has no land detail yet. It's read straight from this
# remote VersaTiles container (no local download).
#
# As of landcover-vectors v2 the container no longer has its own `landcover-vectors` layer:
# its features are written into Shortbread's *own* `land` and `water_polygons` layers using
# standard Shortbread `kind` values, so from_merged_vector folds them straight into the
# matching Shortbread layers and a stock Shortbread style draws them with no extra rules (the
# frontend no longer adds a custom land-cover layer). Set LANDCOVER_URL="" to skip the merge.
# (no colon, so an explicit LANDCOVER_URL="" disables the merge rather than re-defaulting)
#
# NOTE: this must point at a *v2* container. The container published at the URL below is still
# v1 (single `landcover-vectors` layer) as of 2026-06-17 — merging it would leave `land`/
# `water_polygons` empty at low zoom and the v2 frontend would render nothing there. Point this
# at a v2 build (repo `v2` branch → `landcover.versatiles`) once one is published/built.
export LANDCOVER_URL="${LANDCOVER_URL-https://download.versatiles.org/landcover-vectors.versatiles}"
