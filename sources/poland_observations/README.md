# Poland mammal observations

- Original GBIF download: `input/0021372-250426092105405.csv`.
- Source rules: `scripts/sources/poland_observations.R`.
- Input type: `points`; shared processor: `scripts/processors/points.R`.
- Reference grid: `reference/grids/PL/national_grid/pl_10km.shp`.
- Reference eventID: `OKAPL10336`; the registered bibliography is reused.

From the project root, load `scripts/02_prepare_source.R` and call
`prepare_source("poland_observations")`. The file is tab-separated despite its
extension; no manually corrected CSV is needed. The source profile selects the
same eight target species as the historical script, checks the GBIF dataset
identity and interprets status and coordinates explicitly.

The common output is `prepared/records.gpkg`. `record_links` retains original
observation identifiers, dates, uncertainty and license information. Several
observations can support one species/cell/year record. Filtering, invalid
coordinates and unmatched points are reported beside the package.

To reuse the earlier species/year grids instead, call
`prepare_source("poland_observations", use_existing = TRUE)`. Generated zero
rows are omitted. A standard package replaces the old-grid fallback in script 3;
both versions are not added together.
