# Processing workflow

Each source follows the same route:

```text
Original files in sources/<key>/input/
  -> source rules in scripts/sources/<key>.R
  -> shared points, polygons or grids processor
  -> sources/<key>/prepared/records.gpkg
  -> script 3: consolidation, bibliography registration and comparison
  -> database/rebuild/mammals_rebuild.gpkg
```

Use `source("scripts/02_prepare_source.R")` once, then
`prepare_source("dataset_key")` for each source to prepare. Run
`source("scripts/03_add_sources_and_compare.R")` after the desired sources are
ready. The [script guide](../scripts/README.md) contains the commands and the
four prepared tables.

Source rules interpret provider-specific species, dates, statuses and fields.
The shared processor performs the spatial operation. A new source normally
needs a new source profile, not a new processor or a new consolidation branch.
Keep original files unchanged and keep processing code under `scripts/`.

Preparation replaces that source's standard package. Consolidation rereads all
standard packages; it does not repeatedly append the same input. Original
observation and feature links remain in each package's `record_links` table.
Bibliography is provided once in the source profile or reused from the local
source registry. Script 3 registers it and the file links without duplicate IDs.

The starting database has separate one-time steps to extract species by country
and attribute historical event IDs. The source pipeline then adds the prepared
sources to the linked baseline. Unlinked baseline records, missing raw Estonia
points and source groups that have not been reviewed remain explicit limits.
Existing Estonia/Poland grids can be reused and are identified as such.

Missing observations do not establish absence. Multi-year source intervals are
retained instead of being assigned to one year or expanded into annual records.
Input features outside the reference grid and excluded input rows are reported.

Review `processing_report.csv`, `comparison.csv` and `source_coverage.csv` before
accepting a local rebuild. The captured PostgreSQL snapshot remains unchanged.
Applying reviewed changes to PostgreSQL and publishing a DwC-A are later steps;
the local scripts do not perform them.
