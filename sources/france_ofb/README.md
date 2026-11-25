# France OFB distributions

- Original files: `input/`.
- Source rules: `scripts/sources/france_ofb.R`.
- Input type: `polygons`; shared processor: `scripts/processors/polygons.R`.
- Reference grid: `reference/grids/FR/national_grid/fr_10km.shp`.
- Reference eventID: `RESFR30700`.

From the project root, load `scripts/02_prepare_source.R` and call
`prepare_source("france_ofb")`. The common output is `prepared/records.gpkg`,
with processing, exclusion and unmatched-feature reports beside it. Script 3
consolidates this package and its bibliographic reference automatically.

The species mapping, year extraction and spatial intersection rule match the
verified France walkthrough, which produced 30,700 presence records. Original
source attributes and feature-to-record links remain in `record_links`.
The earlier `france_rebuild_test.gpkg` is retained but is not the standard
package used by the finalized pipeline.
