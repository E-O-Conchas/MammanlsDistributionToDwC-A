# European Mammal Distribution

This project brings together European mammal distribution data from atlases,
observation datasets and distribution maps. It standardizes those inputs on
reference grid cells, preserves links to the original records and bibliographic
sources, and prepares the data for publication as a Darwin Core Archive (DwC-A).

[Source registry](reference/source_registry.csv) · [Dataset catalogue](sources/catalogue.csv) · [Processing guide](scripts/README.md) · [Draft export](exports/README.md)

## Geographic coverage and source attribution

The project began with European ungulate distributions on a **10 km grid**
and a separate bibliography. To recover where the data came from, the
bibliography was curated and the distribution layers were traced back to
their sources by country, and by region where applicable. The
[source registry](reference/source_registry.csv) documents the resulting
source groups. The [file crosswalk](reference/source_file_links.csv) connects
those groups to country-specific distribution layers. This establishes
provenance at the layer level where evidence supports the link. Some historical
links remain unresolved, and the original grid does not provide a source for
each individual cell.

The [24 November 2026 PostgreSQL snapshot](database/CURRENT.json) contains
**778,393 grid-based occurrence records across 33 countries**, representing
**20 scientific names** and **78 registered source groups**. The registry
covers mammal atlases, hunting statistics, species range maps, point
observations, district-level occurrence records and abundance data.

The same publication can support several source groups. For example, the
EMMA2 reference is shared by Finland (`EMMFI0376`), Sweden (`EMMSE4817`)
and Montenegro (`EMMME0603`), each with its own link to national layers.
The database stores these source-group identifiers as `eventID`. The
[draft Darwin Core Archive](exports/LATEST.json) carries them into its Event
core. Their interpretation as sampling events, publication metadata and data
quality still require review.

## How the data fit together

1. **Prepare each source.** Source profiles define how to interpret species,
   dates, statuses and provider-specific fields. Shared R processors assign
   observation points and distribution polygons to reference cells or
   standardize compatible grid cells supplied by a provider.
2. **Build and review the local database.** The consolidation script combines
   all prepared sources with the linked historical baseline. It writes
   `database/rebuild/mammals_rebuild.gpkg` and produces comparison and
   source-coverage reports against the captured PostgreSQL snapshot.
3. **Export a draft.** The export tools capture PostgreSQL and generate a
   draft DwC-A from a snapshot. Applying reviewed changes to PostgreSQL and
   publishing an archive are separate steps.

Prepared GeoPackages retain bibliographic references, links to source files
and links from standardized records back to original observations or features.
Multi-year periods are preserved, and unreported cells are treated as unknown.

## Sources supported by automated preparation

| Source | Input | Workflow status |
| --- | --- | --- |
| [France OFB](sources/france_ofb/README.md) | Ungulate distribution polygons | Source preparation implemented |
| [Poland](sources/poland_observations/README.md) | GBIF observation points | Source preparation implemented for eight species |
| [LCIE large carnivores](sources/carnivores_lcie_2017_2023/README.md) | Distribution grid cells | Brown bear enabled. Four other layers await review. |
| [Estonia](sources/estonia_observations/README.md) | Observation points and existing grids | Existing grids can be reused. Original points are missing locally. |

The [source catalogue](sources/catalogue.csv) also lists European Mammal Atlas
material, Saxony, Thuringia, Ireland, Italy and historical wolf data, along with
the remaining work for each source.

## Quick start

Open `mammals_dwc.Rproj` in RStudio and run the commands from the project root.
You need the R package `sf`, the source input files and the relevant local
reference layers. The project also needs a linked baseline for consolidation.
See the [starting database instructions](scripts/README.md#starting-database-and-historical-limits)
if you need to build it first.

```r
source("scripts/02_prepare_source.R")
prepare_source("france_ofb")

source("scripts/03_add_sources_and_compare.R")
```

Replace `"france_ofb"` with the key of the source you want to prepare. You can
rerun preparation for a single source. Consolidation reads all available
prepared packages. Review `processing_report.csv` in the source's prepared
folder and `comparison.csv` and `source_coverage.csv` in `database/rebuild/`.

## Repository guide

| Location | What you’ll find |
| --- | --- |
| [sources/](sources/README.md) | Dataset descriptions and a catalogue. Each dataset has local `input/` and `prepared/` folders. |
| [scripts/](scripts/README.md) | Source profiles, shared R processors, baseline and consolidation scripts, and export tools |
| [reference/](reference/README.md) | Reference grids, country boundaries, bibliographic registry and source-file links |
| [database/](database/README.md) | PostgreSQL snapshot metadata and local rebuild outputs |
| [exports/](exports/README.md) | Draft Darwin Core Archives and review reports |
| [docs/](docs/workflow.md) | Workflow details, provenance and historical coverage limits |
| [archive/](archive/README.md) | Earlier processing scripts and saved project history |

Git tracks code, documentation, dataset descriptions and reference CSVs. Raw
inputs, prepared spatial files, rebuilds, snapshot files, draft archives and
credentials are kept locally and excluded by `.gitignore`. This repository
retains the history of [MammanlsDistributionToDwC-A](https://github.com/E-O-Conchas/MammanlsDistributionToDwC-A).
