# Shortbread 1.1 comparison demo

End-to-end scripts to build the planetiler Shortbread Java profile from the feature branch,
generate worldwide **Shortbread 1.1** tiles, and serve a split-screen map that compares them
against the current OSM tiles from `tiles.versatiles.org`.

## Where this lives

Store this in **`versatiles-org/planetiler-shortbread`** under `demo/` (these scripts are
VersaTiles-specific and shouldn't go into the `planetiler` fork, which stays focused on the Java
profile for a clean upstream PR).

## Usage

Run on a Debian host (12/13). The three steps are independent and re-runnable:

```bash
./01-setup.sh      # install Java 21 + git + versatiles, clone the branch, build the jar
./02-generate.sh   # generate Shortbread 1.1 tiles + convert to a .versatiles container
./03-serve.sh      # serve the comparison map on http://<host>:8080
```

Configuration lives in `config.sh`; override anything via the environment, e.g.:

```bash
AREA=monaco ./02-generate.sh                 # quick smoke test instead of the planet
LANGUAGES=en,de PORT=9000 ./03-serve.sh
```

Languages default to `en,fr,es,de,ar,el,it,nl,pl,pt,uk` (the requested set), emitted as
`name_en`, `name_fr`, … from the OSM `name:<code>` tags.

## What the comparison shows

Both halves use the same VersaTiles **colorful** style, so only the data differs:

- **left half** — current OSM Shortbread tiles from `tiles.versatiles.org`
- **right half** — the locally generated planetiler Shortbread 1.1 tiles, with **ESA WorldCover
  land cover** added underneath at low zoom (see below)

Drag the divider to sweep across. The two maps are camera-synced.

## Low-zoom land cover (issue #1)

OSM-only Shortbread tiles leave the land blank at z0–6 (no land cover — the gap described in
[shortbread-docs#144](https://github.com/shortbread-tiles/shortbread-docs/issues/144)). To fill
it, the right map adds the ESA WorldCover land cover from
[`landcover-vectors`](https://github.com/versatiles-org/landcover-vectors) — this repo implements
**option A** of the issue (no planetiler change).

`02-generate.sh` **merges** the land cover into the generated Shortbread container with the
[VPL](https://github.com/versatiles-org/versatiles-rs) `from_merged_vector` operation, writing one
brotli container — each tile then carries all the Shortbread layers *plus* a `landcover-vectors`
layer (the Shortbread schema is preserved):

```
versatiles convert -c brotli \
  '[,vpl](from_merged_vector [ from_container filename="shortbread.pmtiles", \
                              from_container filename="https://download.versatiles.org/landcover-vectors.versatiles" ])' \
  shortbread.versatiles
```

The land cover container is read **straight from its remote URL** via `from_container`, so nothing
is downloaded locally — `versatiles` range-reads the ~800 MB container on demand during the
convert. `frontend/index.html` then styles the merged-in `landcover-vectors` layer as a single
fill (coloured by the `kind` field with the official ESA WorldCover palette), sitting just above
the background so every OSM layer still draws on top. The land cover is native up to z8, so the
fill fades out by then as the OSM `land` layers fade in.

Configure or disable it in `config.sh` (or via the environment): `LANDCOVER_URL` is the remote
container — set `LANDCOVER_URL=""` to skip the merge and emit a plain Shortbread container.

## ⚠️ Planet build resources

`AREA=planet` downloads the full planet OSM extract (~80 GB) plus the ocean water-polygons
shapefile, and needs a big machine: roughly **64 GB+ RAM** (or memory-mapped storage on a fast
SSD via the default `--storage=mmap`), **~400 GB+ free disk**, and a few hours. Smoke-test with a
small `AREA` first.

## Things to double-check (VersaTiles specifics)

These are pinned to current VersaTiles conventions; verify against your versatiles version if a
step fails:

- **versatiles serve URL scheme** — the demo assumes the source is reachable at
  `/tiles/<SOURCE_ID>/{z}/{x}/{y}`. Open `http://<host>:8080/tiles/` to confirm the mounted path,
  and adjust `LOCAL_TILES_URL` in `frontend/index.html` if it differs.
- **colorful style URL** — `frontend/index.html` fetches
  `https://tiles.versatiles.org/assets/styles/colorful.json`. The same file ships inside
  `frontend.tar`, so you can switch to a local path if you prefer.
- **release asset names** — `01-setup.sh` (versatiles CLI) and `03-serve.sh` (`frontend.tar`)
  resolve download URLs via the GitHub releases API, so they survive asset renames; if a release
  only ships `frontend.br.tar`, extract that instead and serve the `.br` files.
- **`shortbread-1.1` task** — provided by the feature branch; it sets `--shortbread_version=1.1`
  and accepts `--name_languages`.
