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
