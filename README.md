# Shortbread 1.1 comparison demo

End-to-end scripts to build the planetiler Shortbread Java profile from the feature branch,
generate worldwide **Shortbread 1.1** tiles, and serve a split-screen map that compares them
against the current OSM tiles from `tiles.versatiles.org`.

## Where this lives

Store this in **`versatiles-org/planetiler-shortbread`** under `demo/` (these scripts are
VersaTiles-specific and shouldn't go into the `planetiler` fork, which stays focused on the Java
profile for a clean upstream PR).

## Usage

Run on a Debian host (12/13). The steps are independent and re-runnable:

```bash
./01-setup.sh      # install Java 21 + git + versatiles, clone the branch, build the jar
./02-generate.sh   # generate Shortbread 1.1 tiles with planetiler -> shortbread.pmtiles
./03-preview.sh    # OPTIONAL: preview remote Shortbread + land cover, merged in realtime (SFTP)
./04-merge.sh      # merge in the land cover + pack the final brotli .versatiles container
./05-serve.sh      # serve the comparison map on http://<host>:8080
```

`02-generate.sh` is split from the merge so the slow planet build isn't repeated when you
re-merge or re-tune the land cover. `03-preview.sh` is an optional shortcut: it serves an
inline VPL pipeline that feature-merges the *remote* Shortbread and land-cover containers over
SFTP on the fly, so you can eyeball the result before building the local container with
`04-merge.sh`. Configuration lives in `config.sh`; override anything via the environment, e.g.:

```bash
AREA=monaco ./02-generate.sh                 # quick smoke test instead of the planet
LANGUAGES=en,de PORT=9000 ./05-serve.sh

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

`04-merge.sh` **merges** the land cover into the generated Shortbread container with the
[VPL](https://github.com/versatiles-org/versatiles-rs) `from_merged_vector` operation, writing one
brotli container:

```
versatiles convert -c brotli \
  '[,vpl](from_merged_vector [ from_container filename="shortbread.pmtiles", \
                              from_container filename="sftp://u417480.your-storagebox.de/incoming/landcover.versatiles" ])' \
  shortbread.versatiles
```

`from_merged_vector` combines features per layer name. As of **landcover-vectors
[v2](https://github.com/versatiles-org/landcover-vectors/tree/v2)** the land cover no longer has
its own `landcover-vectors` layer — it is written into Shortbread's *own* `land` and
`water_polygons` layers using standard Shortbread `kind` values (`forest`, `farmland`,
`residential`, `sand`, `scrub`, `grassland`, `marsh`, `swamp`, `glacier`, `water`), each emitted
only *below* the zoom where OSM introduces it. So the merge folds the land cover straight into the
matching Shortbread layers and **a stock Shortbread style draws it with no extra rules**:
`frontend/index.html` just repoints the colorful style at the local tiles — its `land-*`/`water-*`
layers carry no `minzoom` and already style every one of those kinds, so the merged-in land cover
appears at low zoom automatically. (No custom land-cover layer or colour table is needed any more;
the data's per-kind zoom cutoffs replace the old client-side fade-out.)

The land cover container is read **straight from its remote URL** via `from_container`, so nothing
is downloaded locally — `versatiles` range-reads the container on demand during the convert.

> **Heads-up:** `LANDCOVER_URL` must point at a **v2** container. While v2 is still being tested it's
> served from the storage box over SFTP
> (`sftp://u417480.your-storagebox.de/incoming/landcover.versatiles`) — `versatiles` range-reads it
> on demand just like an http(s) URL. The container published at
> `download.versatiles.org/landcover-vectors.versatiles` is still **v1** (a single
> `landcover-vectors` layer, max zoom 8); swap `LANDCOVER_URL` to
> `https://download.versatiles.org/landcover.versatiles` once v2 is published there.

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
- **release asset names** — `01-setup.sh` (versatiles CLI) and the `prepare_frontend` helper in
  `config.sh` used by `03-preview.sh`/`05-serve.sh` (`frontend.tar`)
  resolve download URLs via the GitHub releases API, so they survive asset renames; if a release
  only ships `frontend.br.tar`, extract that instead and serve the `.br` files.
- **`shortbread-1.1` task** — provided by the feature branch; it sets `--shortbread_version=1.1`
  and accepts `--name_languages`.
