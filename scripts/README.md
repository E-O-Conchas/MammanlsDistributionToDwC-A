# Source pipeline

Each source is prepared independently. All sources then use the same
consolidation script, regardless of their original format.

## Daily use

Open the project in RStudio and run from the project root:

```r
source("scripts/02_prepare_source.R")
prepare_source("france_ofb")
```

Change the source key to prepare another source:

```r
prepare_source("poland_observations")
prepare_source("carnivores_lcie_2017_2023")
```

Once the desired sources are prepared, consolidate them:

```r
source("scripts/03_add_sources_and_compare.R")
```

Prepare only the source that changed when adding or correcting input. Script 3
reads every standard prepared package, so the other prepared sources remain
included. Repreparing a source replaces its own prepared package. It does not
append another copy of that source to the local database.

## Where scripts belong

```text
scripts/
  01_rebuild_initial_database.R    # Starting grid: species and countries
  02_link_baseline_events.R       # Starting grid: historical attribution
  02_prepare_source.R             # Common source preparation entry point
  03_add_sources_and_compare.R    # Common consolidation and comparison
  processors/
    points.R                     # Observation points -> reference cells
    polygons.R                   # Distribution polygons -> reference cells
    grids.R                      # Supplied cells -> common records
  sources/
    france_ofb.R                 # France paths, fields and species codes
    poland_observations.R        # Poland paths, columns and target species
    carnivores_lcie_2017_2023.R   # Reviewed LCIE fields and bibliography
    estonia_observations.R       # Existing-grid reuse; raw input missing
  export/                        # Snapshot and draft DwC-A tools
```

The three files in `processors/` contain the shared spatial algorithms. The
files in `sources/` contain the rules that depend on the provider: input paths,
field interpretation, species mappings, dates, statuses and bibliographic
references. They do not implement their own spatial intersection algorithm.

For a new source, add its rules under `scripts/sources/<dataset_key>.R`, set
`input_type` to `points`, `polygons` or `grids`, and use the same preparation
command. Script 3 discovers prepared packages automatically; it does not need
a new source-specific branch. Source rules are reviewed code, not automatic
guesses about unfamiliar fields.

## The three input types

| Type | Connected example | What the shared processor does |
| --- | --- | --- |
| `points` | Poland GBIF observations | Assign observations to the reference grid; retain species, year and status |
| `polygons` | France OFB distributions | Assign intersecting distribution polygons to reference cells |
| `grids` | LCIE brown bear | Keep the supplied compatible cells and normalize their attributes |

Poland reads the original tab-separated GBIF download, despite its `.csv`
extension. It selects the same eight species as the historical script and
checks the dataset identity. Other species, invalid coordinates and unmatched
features are reported. Original observation IDs, dates, coordinate uncertainty
and license information remain in the source-level provenance table.

France retains the species mapping, year extraction and intersection rule
verified in the walkthrough. Border intersections remain included. LCIE
retains verbatim periods, names, quality and categories. Multi-year intervals
are not expanded into annual observations. Brown bear is the reviewed LCIE
layer currently enabled; the other four layers still need source review.

Unreported cells are not assigned zero. Explicit source absences can retain
presence code 0. Existing historical grid zeros generated during gridding are
not treated as observed absences.

## Where inputs and outputs belong

```text
sources/<dataset_key>/
  input/                         # Original files, kept unchanged
  prepared/
    records.gpkg                 # Standard output used by script 3
    processing_report.csv        # Counts, matches and exclusions
    excluded_input.csv           # Filtered or invalid input rows
    unmatched_input.csv          # Usable features outside the reference grid
```

Every `records.gpkg` contains four tables:

- `records`: one distribution record per source, country, species, cell,
  year/period and status, with relevant source metadata.
- `sources`: the bibliographic source/event reference.
- `source_files`: links between the source event and input filenames.
- `record_links`: links to the original features or observations, including
  source filenames, source row numbers and the original attributes. Join to
  `records` using `recordKey`.

Several input points or polygons can support the same output record. Their
individual provenance remains in `record_links`. Optional metadata is retained
when prepared sources are combined. A conflicting source reference or duplicate
record scope stops the workflow for review.

Script 3 writes `rebuilt_source_records`, `sources` and `source_files` to
`database/rebuild/mammals_rebuild.gpkg`. It registers references automatically
in the local reference CSV files without duplicate IDs. Comparison and source
coverage reports are written beside the GeoPackage. The original captured
snapshot remains the comparison reference. These scripts do not write to
PostgreSQL or publish a DwC-A.

## Estonia and existing prepared grids

The original Estonia points are not present locally. To explicitly reuse the
existing species/year layers through the same preparation entry point:

```r
prepare_source("estonia_observations", use_existing = TRUE)
```

The same option is available for Poland when reproducing the existing prepared
layers rather than processing its raw download. Script 3 retains the existing
Estonia/Poland grid fallback until a standard package exists for that dataset.
It marks the mode as `reused_prepared_grids`; it does not describe this as a raw
reconstruction. A standard package replaces this fallback for its dataset.

## Starting database and historical limits

To reconstruct the starting grid, first run `01_rebuild_initial_database.R`
and `02_link_baseline_events.R`, then prepare the sources and run script 3.
Do not repeat the starting-grid steps for each new source.

The original separate European grid and boundaries are not available locally.
The baseline uses the cells in the supplied starting shapefile and the local
country layer. Unmatched or ambiguous historical event links remain unresolved.
Script 3 reports the excluded unlinked baseline count; this is not yet a complete
raw reconstruction of every historical source or of historical zero rules.

`recuperar_base.R` remains the saved-session recovery tool. It does not replace
raw preparation. The older France and brown bear entry scripts remain as short
shortcuts to `prepare_source()`; they no longer contain separate processors.

## Code and data in GitHub

Version `scripts/`, `tests/`, the guides and reference CSV files. The existing
Git ignore rules keep raw inputs, prepared spatial data, rebuilds, snapshots
and credentials local. The source profiles are ordinary R files inside
`scripts/`, so their processing decisions remain reviewable in GitHub.

The isolated checks can be run with `Rscript tests/test_source_pipeline.R` from
the project root. They create synthetic inputs in a temporary project and do
not run the real project data.
