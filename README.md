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
- **right half** — the locally generated planetiler Shortbread 1.1 tiles

Drag the divider to sweep across. The two maps are camera-synced.

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
