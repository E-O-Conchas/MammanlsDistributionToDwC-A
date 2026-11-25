# European mammal distribution project

Prepare each source separately, then consolidate all prepared sources with one
shared script. The three supported inputs are observation points, distribution
polygons and compatible grid cells.

From the project root in RStudio:

```r
source("scripts/02_prepare_source.R")
prepare_source("france_ofb")
# Prepare another source by changing the key, then consolidate:
source("scripts/03_add_sources_and_compare.R")
```

See the [run instructions and script locations](scripts/README.md) for the
other source keys and the complete starting-grid rebuild order.

| Location | Contents |
| --- | --- |
| `sources/<dataset>/input/` | Original source files |
| `sources/<dataset>/prepared/` | Standard prepared records and processing reports |
| `scripts/sources/` | Provider-specific paths, field mappings and references |
| `scripts/processors/` | Shared algorithms for points, polygons and grids |
| `reference/` | Grids, boundaries and source-reference CSV files |
| `database/rebuild/` | Consolidated local database and comparison reports |
| `database/snapshots/` | Captured PostgreSQL versions, kept unchanged |
| `exports/` | Draft and release archives |
| `archive/` | Earlier code and saved processing history |

The connected sources are France polygons, Poland observation points and LCIE
brown bear grid cells. Estonia can reuse its existing prepared grids because
the original points are missing locally. The remaining LCIE species and other
historical sources still require review. The baseline reconstruction keeps
unresolved historical source attribution visible rather than guessing it.

The 24 November 2026 PostgreSQL snapshot contains 778,393 occurrence rows,
33 countries and 78 source references. Local preparations and rebuilds are
separate from that captured version. The pipeline registers local bibliography
and file links automatically; applying reviewed changes to PostgreSQL remains
a separate step.

Snapshot export tools remain under `scripts/export/`. The existing draft DwC-A
is under `exports/drafts/20261124T1545482585117Z/` and still needs publication
metadata and data-quality review.

This project retains the history of
[E-O-Conchas/MammanlsDistributionToDwC-A](https://github.com/E-O-Conchas/MammanlsDistributionToDwC-A).
Code, tests, guides, source descriptions and reference CSV files belong in Git.
Raw data, prepared spatial files, snapshots and credentials stay local under
the existing Git ignore rules. Saving pipeline changes does not commit or push
them automatically.
